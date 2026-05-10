import Testing
@testable import ASUSFusionVPN

@Test func settingsValidatorAcceptsNormalRouterFields() throws {
    #expect(try AppSettingsValidator.validatedHost("192.168.1.1") == "192.168.1.1")
    #expect(try AppSettingsValidator.validatedUsername("admin") == "admin")
    #expect(try AppSettingsValidator.validatedPort("22") == 22)
    #expect(try AppSettingsValidator.validatedVPNUnit("5") == 5)
}

@Test func settingsValidatorRejectsUnsafeHostAndUsernameValues() {
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedHost("-oProxyCommand=bad")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedHost("router.local -p 2222")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedUsername("-lroot")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedUsername("admin user")
    }
}

@Test func settingsValidatorRejectsInvalidPortAndUnitValues() {
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedPort("0")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedPort("65536")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedVPNUnit("0")
    }
    #expect(throws: ValidationError.self) {
        try AppSettingsValidator.validatedVPNUnit("-1")
    }
}
