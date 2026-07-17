package ai.digitalmercenaries.ridehorizon.factproxy;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class ProxyAuthFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(ProxyAuthFilter.class);
    private static final String DEVICE_ID_HEADER = "X-RideHorizon-Device-Id";

    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private final RideHorizonProperties properties;
    private final CredentialAuthority credentialAuthority;

    public ProxyAuthFilter(RideHorizonProperties properties, CredentialAuthority credentialAuthority) {
        this.properties = properties;
        this.credentialAuthority = credentialAuthority;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return "/health".equals(path) || "/v1/provision".equals(path) || path.startsWith("/admin/");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String expected = properties.proxyToken();
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        String token = AuthUtils.parseBearerToken(authorization);
        if (token == null) {
            log.warn("event=proxy_auth_failed status=401 reason=missing_bearer");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        boolean sharedCredential = expected != null
                && !expected.isBlank()
                && AuthUtils.tokenEquals(expected, token);
        if (!sharedCredential && !credentialAuthority.authenticate(
                token, request.getHeader(DEVICE_ID_HEADER))) {
            log.warn("event=proxy_auth_failed status=401 reason=wrong_token");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        if (sharedCredential && properties.deviceBindingRequired()) {
            DeviceBindingResult deviceBindingResult = checkDeviceBinding(request);
            if (!deviceBindingResult.allowed) {
                if (deviceBindingResult.misconfigured) {
                    log.error("event=proxy_auth_misconfigured status=500 reason={}", deviceBindingResult.reason);
                    response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, deviceBindingResult.reason);
                } else {
                    log.warn("event=proxy_auth_failed status=401 reason={}", deviceBindingResult.reason);
                    response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
                }
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private DeviceBindingResult checkDeviceBinding(HttpServletRequest request) {
        String normalizedDeviceId = DeviceIdSanitizer.normalize(request.getHeader(DEVICE_ID_HEADER));
        if (normalizedDeviceId == null) {
            return DeviceBindingResult.rejected("missing_device_id");
        }

        var allowedDevices = properties.trustedDeviceIdSet();
        if (allowedDevices.isEmpty()) {
            return DeviceBindingResult.misconfigured("device_binding_enabled_without_allowlist");
        }

        return allowedDevices.contains(normalizedDeviceId)
                ? DeviceBindingResult.allowed()
                : DeviceBindingResult.rejected("unknown_device");
    }

    private static final class DeviceBindingResult {
        private final boolean allowed;
        private final boolean misconfigured;
        private final String reason;

        private DeviceBindingResult(boolean allowed, boolean misconfigured, String reason) {
            this.allowed = allowed;
            this.misconfigured = misconfigured;
            this.reason = reason;
        }

        static DeviceBindingResult allowed() {
            return new DeviceBindingResult(true, false, null);
        }

        static DeviceBindingResult misconfigured(String reason) {
            return new DeviceBindingResult(false, true, reason);
        }

        static DeviceBindingResult rejected(String reason) {
            return new DeviceBindingResult(false, false, reason);
        }
    }
}
