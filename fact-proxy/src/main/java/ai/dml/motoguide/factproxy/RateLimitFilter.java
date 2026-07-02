package ai.dml.motoguide.factproxy;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;

@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    private static final String FLY_CLIENT_IP_HEADER = "Fly-Client-IP";
    private static final String USER_ID_HEADER = "X-MotoGuide-User-Id";
    private static final String DEVICE_ID_HEADER = "X-MotoGuide-Device-Id";
    private static final int MAX_TRACKED_CLIENT_IDENTITIES = 20_000;
    private static final Pattern CLIENT_IP_PATTERN = Pattern.compile("^[0-9a-fA-F:\\.:%]+$");

    private final MotoGuideProperties properties;
    private final Map<String, Deque<Instant>> requestsByIdentity = new BoundedIdentityCache(MAX_TRACKED_CLIENT_IDENTITIES);

    public RateLimitFilter(MotoGuideProperties properties) {
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
        String clientKey = requestIdentityKey(request);
        int limit = Math.max(properties.rateLimitPerMinute(), 1);
        Instant now = Instant.now();
        Instant cutoff = now.minusSeconds(60);

        synchronized (requestsByIdentity) {
            Deque<Instant> timestamps = requestsByIdentity.computeIfAbsent(clientKey, ignored -> new ArrayDeque<>());
            while (!timestamps.isEmpty() && timestamps.peekFirst().isBefore(cutoff)) {
                timestamps.removeFirst();
            }
            if (timestamps.size() >= limit) {
                log.warn("event=rate_limit_exceeded status=429 limitPerMinute={}", limit);
                response.sendError(429, "Rate limit exceeded");
                if (timestamps.isEmpty()) {
                    requestsByIdentity.remove(clientKey);
                }
                return;
            }
            timestamps.addLast(now);
        }

        filterChain.doFilter(request, response);
    }

    private String requestIdentityKey(HttpServletRequest request) {
        String userId = UserIdSanitizer.normalizeAndValidate(request.getHeader(USER_ID_HEADER));
        if (userId != null) {
            return "user:" + userId;
        }
        String deviceId = DeviceIdSanitizer.normalize(request.getHeader(DEVICE_ID_HEADER));
        if (deviceId != null) {
            return "device:" + deviceId;
        }
        return "ip:" + clientIp(request);
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader(FLY_CLIENT_IP_HEADER);
        if (forwarded == null || forwarded.isBlank()) {
            return request.getRemoteAddr();
        }

        String normalized = forwarded.split(",", 2)[0].trim();
        if (normalized.length() > 80 || !CLIENT_IP_PATTERN.matcher(normalized).matches()) {
            return request.getRemoteAddr();
        }
        return normalized;
    }

    private static final class BoundedIdentityCache extends LinkedHashMap<String, Deque<Instant>> {
        private final int maxSize;

        BoundedIdentityCache(int maxSize) {
            super(256, 0.75f, true);
            this.maxSize = maxSize;
        }

        @Override
        protected boolean removeEldestEntry(Map.Entry<String, Deque<Instant>> eldest) {
            return size() > maxSize;
        }
    }
}
