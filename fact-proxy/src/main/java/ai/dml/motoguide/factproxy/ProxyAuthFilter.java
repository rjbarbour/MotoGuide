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

        filterChain.doFilter(request, response);
    }
}
