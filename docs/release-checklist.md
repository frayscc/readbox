# Release Checklist

Use semantic versions in `X.Y.Z` form.

1. Update version references:
   - `VERSION`
   - `backend/app/version.py`
   - `web/package.json` and `web/package-lock.json`
   - `chrome-extension/manifest.json`
   - `ios/project.yml`, then regenerate `ios/ReadBox.xcodeproj`
2. Run verification:
   - `backend/.venv/bin/python -m pytest -q`
   - `npm run build --prefix web`
   - `xcrun swiftc -parse ios/Shared/*.swift ios/ReadBox/*.swift ios/ReadBoxShareExtension/*.swift`
   - `xcodebuild -project ios/ReadBox.xcodeproj -scheme ReadBox -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
   - `docker build -t frayscc/readbox:backend-X.Y.Z -f backend/Dockerfile backend`
3. Commit changes and tag:
   - `git tag vX.Y.Z`
4. Push GitHub:
   - `git push origin main`
   - `git push origin vX.Y.Z`
5. Publish Docker images:
   - `frayscc/readbox:backend-X.Y.Z`
   - `frayscc/readbox:web-X.Y.Z`
   - update `backend-latest` and `web-latest` when appropriate
6. Create or update the GitHub Release with release notes and any build artifacts.
