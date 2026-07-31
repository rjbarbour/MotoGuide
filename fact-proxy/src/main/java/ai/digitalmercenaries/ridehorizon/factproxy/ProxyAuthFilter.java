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
    static final String SESSION_AUTH_ATTRIBUTE = "rhSessionAuth";
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private final SessionAuthority sessionAuthority;

    public ProxyAuthFilter(SessionAuthority sessionAuthority) {
        this.sessionAuthority = sessionAuthority;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return "/health".equals(path)
                || "/v1/session/fallback".equals(path)
                || path.startsWith("/admin/");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        String token = AuthUtils.parseBearerToken(authorization);
        if (token == null) {
            log.warn("event=proxy_auth_failed status=401 reason=missing_bearer");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        SessionAuthority.SessionAuthentication auth = sessionAuthority.authenticate(token);
        if (auth == null) {
            log.warn("event=proxy_auth_failed status=401 reason=unauthenticated");
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }
        request.setAttribute(SESSION_AUTH_ATTRIBUTE, auth);

        filterChain.doFilter(request, response);
    }

}
