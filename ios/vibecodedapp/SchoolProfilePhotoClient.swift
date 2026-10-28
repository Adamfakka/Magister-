import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit
import ImageIO

private struct SchoolProfilePhotoResponse: Decodable {
    let data: Photo
    struct Photo: Decodable { let url: String }
}

private struct SchoolProfilePhotoErrorEnvelope: Decodable {
    let error: Detail
    struct Detail: Decodable { let message: String }
}

private enum SchoolProfilePhotoError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        }
    }
}

/// All selected-image bytes stay in memory and are released on cancel/success.
/// Network access happens only from upload(), after the explicit consent button.
@Observable @MainActor
final class SchoolProfilePhotoViewModel {
    private(set) var isPreparing = false
    private(set) var isUploading = false
    private(set) var preview: UIImage?
    var errorMessage: String?
    @ObservationIgnored private var pendingJPEG: Data?

    var isBusy: Bool { isPreparing || isUploading }
    var hasPendingPhoto: Bool { pendingJPEG != nil }

    func prepare(_ item: PhotosPickerItem) async {
        guard !isBusy else { return }
        discard()
        isPreparing = true
        defer { isPreparing = false }
        print("[ProfilePhoto] Reading selected photo locally; no upload yet")
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw SchoolProfilePhotoError.message("Deze foto kon niet worden gelezen. Kies een andere foto.")
            }
            try Task.checkCancellation()
            guard data.count <= 25 * 1024 * 1024 else {
                throw SchoolProfilePhotoError.message("Deze foto is te groot. Kies een foto van maximaal 25 MB.")
            }
            // Downsample rather than decode a full-resolution image. Re-encoding
            // strips EXIF/location metadata and normalizes HEIC/PNG into JPEG.
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1024,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else {
                throw SchoolProfilePhotoError.message("Deze foto kon niet worden verwerkt. Kies een andere foto.")
            }
            let image = UIImage(cgImage: thumbnail)
            guard let jpeg = image.jpegData(compressionQuality: 0.8), jpeg.count <= 5 * 1024 * 1024 else {
                throw SchoolProfilePhotoError.message("Deze foto kon niet worden verkleind. Kies een andere foto.")
            }
            try Task.checkCancellation()
            pendingJPEG = jpeg
            preview = image
            print("[ProfilePhoto] Local preview ready; waiting for upload consent")
        } catch is CancellationError {
            discard()
            print("[ProfilePhoto] Local selection cancelled")
        } catch {
            errorMessage = error.localizedDescription
            print("[ProfilePhoto] Photo preparation failed: \(error)")
        }
    }

    @discardableResult
    func upload(to store: SchoolProfileStore) async -> Bool {
        guard !isBusy, let jpeg = pendingJPEG, store.loadError == nil else { return false }
        isUploading = true
        errorMessage = nil
        let revision = store.photoRevision
        defer { isUploading = false }
        print("[ProfilePhoto] User consented; uploading resized photo through backend")
        do {
            let base = AppConfig.string("IOS_BACKEND_URL") ?? ""
            guard var components = URLComponents(string: base),
                  ["https", "http"].contains(components.scheme ?? ""), components.host != nil else {
                throw SchoolProfilePhotoError.message("De uploadservice is niet ingesteld. Probeer het later opnieuw.")
            }
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + (components.path.isEmpty ? "" : components.path + "/") + "api/profile/photo"
            components.query = nil
            components.fragment = nil
            guard let url = components.url else {
                throw SchoolProfilePhotoError.message("De uploadservice is niet bereikbaar.")
            }
            let request = photoRequest(url: url, jpeg: jpeg)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200..<300).contains(http.statusCode) else {
                let envelope = try? JSONDecoder().decode(SchoolProfilePhotoErrorEnvelope.self, from: responseData)
                let message = envelope?.error.message
                throw SchoolProfilePhotoError.message(message ?? "Uploaden is niet gelukt. Probeer het opnieuw.")
            }
            let result = try JSONDecoder().decode(SchoolProfilePhotoResponse.self, from: responseData)
            guard let cdnURL = URL(string: result.data.url), cdnURL.scheme == "https",
                  let host = cdnURL.host, host == "staticfiles.net" || host.hasSuffix(".staticfiles.net") else {
                throw SchoolProfilePhotoError.message("De uploadservice gaf geen geldige foto terug.")
            }
            guard store.setPhotoURL(result.data.url, expectedRevision: revision) else {
                throw SchoolProfilePhotoError.message(
                    "Je profiel is intussen gewist of gewijzigd. De foto is niet aan je profiel toegevoegd."
                )
            }
            discard()
            print("[ProfilePhoto] Photo URL saved locally; selected bytes released")
            return true
        } catch {
            errorMessage = error is CancellationError || (error as? URLError)?.code == .cancelled
                ? "Uploaden is geannuleerd. Je vorige profielfoto is behouden."
                : error.localizedDescription
            print("[ProfilePhoto] Upload failed; previous avatar preserved: \(error)")
            return false
        }
    }

    private func photoRequest(url: URL, jpeg: Data) -> URLRequest {
        let boundary = "Photo-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var body = Data()
        let consentPart = "--\(boundary)\r\nContent-Disposition: form-data; name=\"consent\"\r\n\r\ntrue\r\n"
        let photoPart = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; "
            + "filename=\"profile-photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"
        body.append(Data(consentPart.utf8))
        body.append(Data(photoPart.utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        return request
    }

    func discard() {
        pendingJPEG = nil
        preview = nil
        errorMessage = nil
    }
}
