    import OpenAPIRuntime
    import Foundation

    extension APIHandler {

        func getCurrentRound(_ input: Operations.getCurrentRound.Input) async throws -> Operations.getCurrentRound.Output {
            let db = app.db
            guard let gameId = Foundation.UUID(uuidString: input.path.gameId) else {
                return .undocumented(statusCode: 404, .init())
            }

            let roundService = RoundService(db: db)
            guard let round = try await roundService.getCurrentRound(gameId: gameId) else {
                return .undocumented(statusCode: 404, .init())
            }


            // currentPhase 
            let phase: Components.Schemas.RoundPhase
            switch round.currentPhase {
            case .upload:
                phase = .upload
            case .guess:
                phase = .guess
            case .calculateResults:
                phase = .calculateResults
            }

            // Fotografen für diese Runde laden
            guard let roundId = round.id else {
                return .undocumented(statusCode: 404, .init())
            }
            let photographers = try await RoundPhotographer.query(on: db)
                .filter(\RoundPhotographer.$round.$id, .equal, roundId)
                .all()

            let photographerAssignments = photographers.map { p in
                Components.Schemas.RoundPhotographerAssignment(
                    teamId: p.$team.id.uuidString,
                    userId: p.$user.id.uuidString
                )
            }

            return .ok(.init(body: .json(.init(
                id: roundId.uuidString,
                roundNumber: round.roundNumber,
                phase: phase,
                deadline: round.deadline,
                photographers: photographerAssignments
            ))))
        }

        func uploadPhoto(_ input: Operations.uploadPhoto.Input) async throws -> Operations.uploadPhoto.Output {
            let minioService = MinIOService()
            let db = app.db
            guard let gameId = Foundation.UUID(uuidString: input.path.gameId) else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // TODO: photographerId aus JWT lesen
            let photographerIdOptional: Foundation.UUID? = nil
            guard let photographerId: Foundation.UUID = photographerIdOptional else {
                 return .undocumented(statusCode: 401, .init())
             }
            
            guard case .multipartForm(let multipart) = input.body else {
                return .undocumented(statusCode: 400, .init())
            }
            
            var photoData: Foundation.Data? = nil
            var latitude: Double? = nil
            var longitude: Double? = nil
            var hint: String? = nil
            
            for try await part in multipart {
                switch part {
                case .photo(let photoPart):
                    let bytes = try await [UInt8](collecting: photoPart.payload.body, upTo: 10 * 1024 * 1024)
                    photoData = Foundation.Data(bytes)
                case .latitude(let latPart):
                    let bytes = try await [UInt8](collecting: latPart.payload.body, upTo: 100)
                    latitude = Double(String(bytes: bytes, encoding: .utf8) ?? "")
                case .longitude(let lngPart):
                    let bytes = try await [UInt8](collecting: lngPart.payload.body, upTo: 100)
                    longitude = Double(String(bytes: bytes, encoding: .utf8) ?? "")
                case .hint(let hintPart):
                    let bytes = try await [UInt8](collecting: hintPart.payload.body, upTo: 1000)
                    hint = String(bytes: bytes, encoding: .utf8)
                case .undocumented:
                    break
                }
            }
            
            guard let photoData, let latitude, let longitude else {
                return .undocumented(statusCode: 400, .init())
            }
            
            // Aktuelle Runde finden (Phase = uploading)
            guard let round = try await Round.query(on: db)
                .filter(\Round.$game.$id, .equal, gameId)
                .filter(\Round.$currentPhase, .equal, Round.CurrentPhase.upload)
                .first(),
                let roundId = round.id
            else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Prüfen ob die Upload-Deadline überschritten ist
            if let deadline = round.deadline, deadline < Date() {
                return .undocumented(statusCode: 410, .init())
            }
            
            // Prüfen ob bereits ein Foto von diesem Fotografen für diese Runde existiert
            let existingPhoto = try await Photo.query(on: db)
                .filter(\Photo.$round.$id, .equal, roundId)
                .filter(\Photo.$photographer.$id, .equal, photographerId)
                .first()
            
            guard existingPhoto == nil else {
                return .undocumented(statusCode: 409, .init())
            }
            
            let key = "\(input.path.gameId)/\(Foundation.UUID().uuidString).jpg"
            _ = try await minioService.upload(data: photoData, key: key)
            
            let photo = Photo(
                roundId: roundId,
                photographerId: photographerId,
                latitude: latitude,
                longitude: longitude,
                hint: hint,
                photoURL: key
            )
            try await photo.save(on: db)

            let roundService = RoundService(db: db)
            try await roundService.checkBothTeamsUploaded(gameId: gameId, round: round)

            return .created(.init())
        }

        func replacePhoto(_ input: Operations.replacePhoto.Input) async throws -> Operations.replacePhoto.Output {
            let minioService = MinIOService()
            let db = app.db
            
            guard let gameId = Foundation.UUID(uuidString: input.path.gameId) else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // TODO: photographerId aus JWT lesen 
            let photographerIdOptional: Foundation.UUID? = nil
            guard let photographerId: Foundation.UUID = photographerIdOptional else {
                return .undocumented(statusCode: 401, .init())
            }

            guard case .multipartForm(let multipart) = input.body else {
                return .undocumented(statusCode: 400, .init())
            }

            var photoData: Foundation.Data? = nil
            var latitude: Double? = nil
            var longitude: Double? = nil
            var hint: String? = nil

            for try await part in multipart {
                switch part {
                case .photo(let photoPart):
                    let bytes = try await [UInt8](collecting: photoPart.payload.body, upTo: 10 * 1024 * 1024)
                    photoData = Foundation.Data(bytes)
                case .latitude(let latPart):
                    let bytes = try await [UInt8](collecting: latPart.payload.body, upTo: 100)
                    latitude = Double(String(bytes: bytes, encoding: .utf8) ?? "")
                case .longitude(let lngPart):
                    let bytes = try await [UInt8](collecting: lngPart.payload.body, upTo: 100)
                    longitude = Double(String(bytes: bytes, encoding: .utf8) ?? "")
                case .hint(let hintPart):
                    let bytes = try await [UInt8](collecting: hintPart.payload.body, upTo: 1000)
                    hint = String(bytes: bytes, encoding: .utf8)
                case .undocumented:
                    break
                }
            }

            guard let photoData, let latitude, let longitude else {
                return .undocumented(statusCode: 400, .init())
            }

            // Aktuelle Runde finden (Phase = uploading)
            guard let round = try await Round.query(on: db)
                .filter(\Round.$game.$id, .equal, gameId)
                .filter(\Round.$currentPhase, .equal, Round.CurrentPhase.upload)
                .first(),
                let roundId = round.id
            else {
                return .undocumented(statusCode: 404, .init())
            }

            // Prüfen ob die Upload-Deadline überschritten ist
            if let deadline = round.deadline, deadline < Date() {
                return .undocumented(statusCode: 410, .init())
            }

            // Bestehendes Foto dieses Fotografen für diese Runde laden
            guard let existingPhoto = try await Photo.query(on: db)
                .filter(\Photo.$round.$id, .equal, roundId)
                .filter(\Photo.$photographer.$id, .equal, photographerId)
                .first()
            else {
                return .undocumented(statusCode: 404, .init())
            }

            // Neues Bild hochladen
            let oldKey = existingPhoto.photoURL
            let newKey = "\(input.path.gameId)/\(Foundation.UUID().uuidString).jpg"
            _ = try await minioService.upload(data: photoData, key: newKey)

            // Metadaten aktualisieren
            existingPhoto.photoURL = newKey
            existingPhoto.latitude = latitude
            existingPhoto.longitude = longitude
            existingPhoto.hint = hint
            try await existingPhoto.save(on: db)

            // Altes Bild aus MinIO löschen
            try? await minioService.delete(key: oldKey)

            return .ok(.init())
        }
        
        func deletePhoto(_ input: Operations.deletePhoto.Input) async throws -> Operations.deletePhoto.Output {
            let minioService = MinIOService()
            let db = app.db
            
            guard let gameId = Foundation.UUID(uuidString: input.path.gameId) else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // TODO: photographerId aus JWT lesen
            let photographerIdOptional: Foundation.UUID? = nil
            guard let photographerId: Foundation.UUID = photographerIdOptional else {
                return .undocumented(statusCode: 401, .init())
            }

            // Aktuelle Runde finden (Phase = uploading)
            guard let round = try await Round.query(on: db)
                .filter(\Round.$game.$id, .equal, gameId)
                .filter(\Round.$currentPhase, .equal, Round.CurrentPhase.upload)
                .first(),
                let roundId = round.id
            else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Prüfen ob die Upload-Deadline überschritten ist
            if let deadline = round.deadline, deadline < Date() {
                return .undocumented(statusCode: 410, .init())
            }
            
            // Bestehendes Foto dieses Fotografen für diese Runde laden
            guard let photo = try await Photo.query(on: db)
                .filter(\Photo.$round.$id, .equal, roundId)
                .filter(\Photo.$photographer.$id, .equal, photographerId)
                .first()
            else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Foto aus MinIO löschen
            try? await minioService.delete(key: photo.photoURL)
            
            // Eintrag aus DB löschen
            try await photo.delete(on: db)
            
            return .noContent(.init())
        }

        func getUploadStatus(_ input: Operations.getUploadStatus.Input) async throws -> Operations.getUploadStatus.Output {
            let db = app.db
            guard let gameId = Foundation.UUID(uuidString: input.path.gameId) else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Aktuelle Runde finden (Phase = uploading)
            guard let round = try await Round.query(on: db)
                .filter(\Round.$game.$id, .equal, gameId)
                .filter(\Round.$currentPhase, .equal, Round.CurrentPhase.upload)
                .first(),
                let roundId = round.id
            else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Beide Teams für dieses Spiel finden
            // MVP-Annahme: genau zwei Teams pro Spiel
            let participates = try await Participate.query(on: db)
                .filter(\Participate.$game.$id, .equal, gameId)
                .all()
            
            guard participates.count == 2 else {
                return .undocumented(statusCode: 404, .init())
            }
            
            // Fotos der aktuellen Runde laden
            let photos = try await Photo.query(on: db)
                .filter(\Photo.$round.$id, .equal, roundId)
                .all()
            
            // Für jedes Foto: User -> Team über TeamMember finden
            var photographerTeamIds = Set<Foundation.UUID>()
            for photo in photos {
                if let teamMember = try await TeamMember.query(on: db)
                    .filter(\TeamMember.$user.$id, .equal, photo.$photographer.id)
                    .filter(\TeamMember.$game.$id, .equal, gameId)
                    .first()
                {
                    photographerTeamIds.insert(teamMember.$team.id)
                }
            }
            
            // Prüfen ob Team A / Team B hochgeladen haben
            let teamAId = participates[0].$team.id
            let teamBId = participates[1].$team.id
            
            let teamAUploaded = photographerTeamIds.contains(teamAId)
            let teamBUploaded = photographerTeamIds.contains(teamBId)
            
            return .ok(.init(body: .json(.init(
                teamA: teamAUploaded ? .uploaded : .pending,
                teamB: teamBUploaded ? .uploaded : .pending
            ))))
        }
    }