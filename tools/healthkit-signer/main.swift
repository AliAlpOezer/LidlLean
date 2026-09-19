// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import SideSign
import CodeSignKit

// Required by the upstream CLI support files compiled into this target.
func ~= (pattern: [String]?, value: String) -> Bool {
    pattern?.contains(value) ?? false
}

struct Stop: Error { let reason: String }
var failurePhase = "startup"

func require(_ condition: Bool, _ reason: String) throws {
    if !condition { throw Stop(reason: reason) }
}

func secret(_ prompt: String) throws -> String {
    guard let value = SecureInput.readPassword(prompt: prompt), !value.isEmpty else {
        throw Stop(reason: "A private interactive console and a nonempty password are required.")
    }
    return value
}

func line(_ prompt: String) throws -> String {
    print(prompt, terminator: " ")
    guard let value = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        throw Stop(reason: "Cancelled.")
    }
    return value
}

func profileGate(_ profile: ProvisioningProfile, bundle: String, team: String, udid: String) throws {
    try require(profile.entitlements["com.apple.developer.healthkit"] as? Bool == true,
                "Apple's profile does not authorize HealthKit. Nothing was signed.")
    try require(profile.bundleIdentifier == bundle && profile.teamIdentifier == team,
                "Apple returned a different app or team identity.")
    try require(profile.expirationDate > Date().addingTimeInterval(300), "Profile expires too soon.")
    try require(profile.deviceIDs.contains(udid), "Profile does not include the requested iPhone.")
}

func twoFactor(_ request: TwoFactorRequest) async throws -> TwoFactorResponse {
    switch request {
    case .selectDeliveryMethod:
        return .requestTrustedDevice
    case .trustedDevice, .sms, .voice:
        let code = try secret("Apple verification code (blank cancels): ")
        try require(code.count == 6 && code.allSatisfy(\.isNumber), "Expected a six-digit Apple code.")
        return .verificationCode(code)
    }
}

func run() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    if args == ["--help"] || args.isEmpty {
        print("LidlLean experimental HealthKit signer. Run Start-HealthKitSigning.ps1, not this executable directly.")
        print("Options: --app PATH --state PATH --libs PATH --bundle-id ID --udid ID")
        return
    }
    if args == ["--self-test"] {
        let xml = "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>"
        guard let der = DEREncoder.encodePlistXML(xml) else { throw Stop(reason: "Self-test failed: DER encoding unavailable.") }
        let boolean = Array(der.suffix(3))
        try require(boolean.count == 3 && boolean[0] == 1 && boolean[1] == 1 && boolean[2] != 0,
                    "Self-test failed: XML HealthKit Boolean became a non-Boolean DER value.")
        let empty = ProvisioningProfile(name: "test", uuid: UUID(), bundleIdentifier: "com.alial.lidllean",
            teamIdentifier: "TESTTEAM00", teamName: "Test", creationDate: Date(),
            expirationDate: Date().addingTimeInterval(600), deviceIDs: ["test"], data: Data())
        do {
            try profileGate(empty, bundle: "com.alial.lidllean", team: "TESTTEAM00", udid: "test")
            throw Stop(reason: "Self-test failed: empty profile accepted.")
        } catch let error as Stop {
            try require(error.reason.contains("does not authorize"), "Self-test failed.")
        }
        print("PASS: HealthKit Boolean preserved in DER; missing profile rejected; no network or credentials used.")
        return
    }
    let allowed: Set<String> = ["--app", "--state", "--libs", "--bundle-id", "--udid"]
    var options: [String: String] = [:]
    try require(args.count == allowed.count * 2, "Use the PowerShell launcher. Missing or extra arguments.")
    for i in stride(from: 0, to: args.count, by: 2) {
        try require(allowed.contains(args[i]) && options[args[i]] == nil, "Unknown or duplicate argument.")
        options[args[i]] = args[i + 1]
    }
    let app = URL(fileURLWithPath: options["--app"]!)
    let state = URL(fileURLWithPath: options["--state"]!)
    let bundle = options["--bundle-id"]!
    let udid = options["--udid"]!
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: app.appendingPathComponent("Info.plist")), format: nil) as? [String: Any]
    try require(info?["CFBundleIdentifier"] as? String == bundle, "Input bundle identifier differs. Refusing to change app identity.")
    try require(!FileManager.default.fileExists(atPath: app.appendingPathComponent("PlugIns").path), "App extensions are not supported by this helper.")
    try require(AnisetteDataManager.validateLibrariesExist(at: URL(fileURLWithPath: options["--libs"]!)),
                "Local ADI libraries are missing. See README; no public anisette service is used.")

    let vaultPassword = try secret("Local vault password (encrypts your signing key and device state): ")
    let portalOptions = PortalOptions(deviceDataPath: state.appendingPathComponent("device.dat").path,
        deviceDataPassword: vaultPassword, localAnisetteDir: options["--libs"]!)
    failurePhase = "local Apple-device authentication data"
    let (anisette, _, _, _) = try await CommandHandler.fetchAnisetteHeaders(options: portalOptions)
    failurePhase = "Apple Account sign-in"
    let email = try line("Apple Account email:")
    let password = try secret("Apple Account password (never saved): ")
    let portal = DeveloperPortal()
    let auth = try await portal.authenticate(appleID: email, password: password, anisetteData: anisette,
        xcodeVersion: "26.0", accountRepairHandler: { _, _ in .cancel }, verificationHandler: twoFactor)
    failurePhase = "developer-team lookup"
    let teams = try await portal.fetchTeams(for: auth.account, session: auth.session)
    try require(!teams.isEmpty, "Apple returned no developer teams. Accept the free developer agreement on Apple's website.")
    for (index, team) in teams.enumerated() { print("\(index + 1). \(team.name) [\(team.identifier)] \(team.type.displayName)") }
    let selection = Int(try line("Select the Personal Team number:")) ?? 0
    try require(selection > 0 && selection <= teams.count, "Invalid team selection.")
    let team = teams[selection - 1]
    try require(team.type == .free, "This experiment is limited to a recognized free Personal Team.")
    print("Target: \(bundle), team \(team.identifier), iPhone \(udid).")
    print("May register this device/App ID and enable HealthKit. No apps are installed and no certificates revoked.")
    try require(try line("Type PROVISION to continue:") == "PROVISION", "Cancelled before account changes.")

    failurePhase = "app identifier provisioning"
    let appIDs = try await portal.fetchAppIDs(for: team, session: auth.session)
    var appID: AppID
    if let existing = appIDs.first(where: { $0.bundleIdentifier == bundle }) { appID = existing }
    else { appID = try await portal.addAppID(withName: "LidlLean", bundleIdentifier: bundle, team: team, session: auth.session) }
    appID.features[Feature("HK421J6T7P")] = "true"
    appID = try await portal.updateAppID(appID, team: team, session: auth.session)
    failurePhase = "iPhone registration"
    let devices = try await portal.fetchDevices(for: team, types: .iPhone, session: auth.session)
    if !devices.contains(where: { $0.identifier == udid }) {
        _ = try await portal.registerDevice(name: "LidlLean iPhone", identifier: udid, type: .iPhone, team: team, session: auth.session)
    }

    failurePhase = "local signing key"
    let keyURL = state.appendingPathComponent("\(team.identifier).p12")
    let keyStore: KeyStore
    if FileManager.default.fileExists(atPath: keyURL.path) {
        keyStore = try KeyStore(p12Data: Data(contentsOf: keyURL), password: vaultPassword)
    } else {
        print("No local signing key for this team. Creating a certificate consumes a free-account slot.")
        try require(try line("Type CREATE to create one, or cancel and import your own encrypted P12:") == "CREATE", "Cancelled. No certificate created.")
        failurePhase = "development certificate creation"
        keyStore = try await portal.addCertificate(machineName: "LidlLean Windows", type: .development, to: team, session: auth.session)
        try keyStore.exportP12(password: vaultPassword).write(to: keyURL, options: .atomic)
        print("Encrypted signing key saved. Keep this vault and password for renewals.")
    }
    failurePhase = "HealthKit provisioning profile request"
    let profile = try await portal.downloadProvisioningProfile(for: appID, team: team, session: auth.session)
    try profileGate(profile, bundle: bundle, team: team.identifier, udid: udid)
    try require(profile.certificates.contains(where: { $0.serialNumberHex == keyStore.certificate.serialNumberHex }),
                "Profile does not authorize the saved signing certificate. No revocation or replacement was attempted.")
    try profile.data.write(to: state.appendingPathComponent("last.mobileprovision"), options: .atomic)
    print("Apple's profile includes HealthKit. Signing the working copy...")
    failurePhase = "local app signing"
    try await AppBundleSigner(team: team, keyStore: keyStore).signApp(at: app, provisioningProfiles: [profile])
    let verification = CodeSignKit.SignatureVerifier.verify(url: app, deep: true, strict: true)
    try require(verification.isValid, "Signer verification failed. Do not install the working copy.")
    print("Signing finished. The launcher must independently inspect the output before packaging.")
}

do {
    SideSignLogging.setLogging(false)
    try await run()
} catch let error as Stop {
    print("STOP: \(error.reason)")
    exit(1)
} catch {
    // Upstream errors can contain raw server payloads. Never echo them.
    print("STOP: \(failurePhase) failed. No install was attempted.")
    print("Check connectivity, your vault password and Apple's account status. Do not send credentials or session files for diagnosis.")
    exit(1)
}
