# Licensing and distribution review

This records the technical licensing checks for the initial preview. It is not a jurisdiction-wide trademark clearance or a legal opinion on every possible use of the software.

## Code and notices

- Project source is offered under MIT, with the full license in the repository and the app bundle.
- The chip/sensor catalog adapts community mapping facts from Stats. Its revision, author, MIT copyright notice and full license text are retained in THIRD_PARTY_NOTICES.md, also copied into the app bundle.
- Package.swift declares no external package dependencies. The app links platform frameworks supplied by macOS.
- No third-party commercial executable, helper, recovered function body, icon or licensing material is included in the source tree or distributed app. The implementation and bounded helper protocol were written independently.
- The read-only linkage investigation is described with its actual limits; this project does not claim a formal clean-room certification.

## Artwork and names

- The owner supplied the SkyTruong palette and requested new fan artwork. The app uses newly generated fan/airflow artwork and does not reuse the ST monogram or wordmark. The original reference files are excluded from publication.
- Raster-generation provenance is stated in assets/brand/README.md. General color combinations and AI-generated elements are not claimed as exclusive intellectual property. The project license grants permissions to the extent the contributors hold the corresponding rights.
- My Fan Control is presented as an independent project. References to macOS/Apple or Macs Fan Control/CrystalIDEA identify compatibility, investigated artifacts or conflicting utilities; they do not imply affiliation, endorsement or a trademark license.
- App name and worldwide trademark availability have not been formally cleared. Avoid presenting it as an official Apple or CrystalIDEA product.

## Claims and installation

- The initial release is explicitly a preview. Real fan writes, administrator authorization, physical recovery/thermal testing and other Mac models remain unverified. Monitoring observations and fake-hardware tests are identified separately.
- The software is provided under the MIT warranty disclaimer. The documentation does not promise hardware protection, thermal safety or complete compatibility with another product.
- The distributed app is ad-hoc signed. The host had no Developer ID Application identity, and local Gatekeeper assessment rejected the ad-hoc bundle. It is not advertised as notarized or as opening without a macOS warning.
- Preview installation documents Apple's per-app Open Anyway flow, source verification and standard Applications installation. It does not instruct users to disable Gatekeeper/SIP or remove quarantine.
- The app stores presets/schedules locally, has no account/analytics/cloud service, and launches the user's browser only when a reference link is chosen.

## Release contents

The release package includes the app, installation instructions, source/release references, license notices and SHA-256 checksums. Local workspace settings, raw device snapshots, original brand files and temporary generation artifacts are excluded. `.codex/` is ignored and absent from the release tree; earlier development history may still contain its former non-secret Run configuration.
