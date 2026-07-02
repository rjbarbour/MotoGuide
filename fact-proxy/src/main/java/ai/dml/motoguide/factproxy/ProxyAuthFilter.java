package ai.dml.motoguide.factproxy;

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
    private static final String DEVICE_ID_HEADER = "X-MotoGuide-Device-Id";

    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private final MotoGuideProperties properties;

    public ProxyAuthFilter(MotoGuideProperties properties) {
        this.properties = properties;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return "/health".equals(path) || path.startsWith("/admin/");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String expected = properties.proxyToken();
        if (expected == null || expected.isBlank()) {
            log.error("event=proxy_auth_misconfigured status=500");
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Proxy token is not configured");
            return;
        }

        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        String token = AuthUtils.parseBearerToken(authorization);
        if (token == null) {
            log.warn("event=proxy_auth_failed status=401 reason=missing_bearer");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        if (!AuthUtils.tokenEquals(expected, token)) {
            log.warn("event=proxy_auth_failed status=401 reason=wrong_token");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        if (properties.deviceBindingRequired()) {
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
