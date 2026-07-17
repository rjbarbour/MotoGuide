package ai.digitalmercenaries.ridehorizon.factproxy;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;

@Component
final class AdminAuthorizer {
    private final RideHorizonProperties properties;

    AdminAuthorizer(RideHorizonProperties properties) {
        this.properties = properties;
    }

    boolean isConfigured() {
        return expectedToken() != null;
    }

    boolean isAuthorized(HttpServletRequest request) {
        String expected = expectedToken();
        String supplied = AuthUtils.parseBearerToken(request.getHeader(HttpHeaders.AUTHORIZATION));
        return expected != null && supplied != null && AuthUtils.tokenEquals(expected, supplied);
    }

    private String expectedToken() {
        if (properties.adminToken() != null && !properties.adminToken().isBlank()) {
            return properties.adminToken();
        }
        if (properties.proxyToken() != null && !properties.proxyToken().isBlank()) {
            return properties.proxyToken();
        }
        return null;
    }
}
