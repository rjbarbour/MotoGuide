package ai.digitalmercenaries.ridehorizon.factproxy;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Clock;
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
    private static final String USER_ID_HEADER = "X-RideHorizon-User-Id";
    private static final String DEVICE_ID_HEADER = "X-RideHorizon-Device-Id";
    private static final int MAX_TRACKED_CLIENT_IDENTITIES = 20_000;
    private static final Pattern CLIENT_IP_PATTERN = Pattern.compile("^[0-9a-fA-F:\\.:%]+$");

    private final RideHorizonProperties properties;
    private final Clock clock;
    private final Map<String, Deque<Instant>> requestsByIdentity = new BoundedIdentityCache(MAX_TRACKED_CLIENT_IDENTITIES);

    public RateLimitFilter(RideHorizonProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return "/health".equals(path);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String clientKey = requestIdentityKey(request);
        int limit = Math.max(properties.rateLimitPerMinute(), 1);
        Instant now = clock.instant();
        Instant cutoff = now.minusSeconds(60);

        synchronized (requestsByIdentity) {
            pruneExpiredIdentities(cutoff);
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

    @Scheduled(
            initialDelayString = "${ridehorizon.rate-limit-privacy-cleanup-delay-ms:60000}",
            fixedDelayString = "${ridehorizon.rate-limit-privacy-cleanup-delay-ms:60000}"
    )
    void purgeExpiredIdentities() {
        Instant cutoff = clock.instant().minusSeconds(60);
        synchronized (requestsByIdentity) {
            pruneExpiredIdentities(cutoff);
        }
    }

    int trackedIdentityCount() {
        synchronized (requestsByIdentity) {
            return requestsByIdentity.size();
        }
    }

    private void pruneExpiredIdentities(Instant cutoff) {
        requestsByIdentity.entrySet().removeIf(entry -> {
            Deque<Instant> timestamps = entry.getValue();
            while (!timestamps.isEmpty() && timestamps.peekFirst().isBefore(cutoff)) {
                timestamps.removeFirst();
            }
            return timestamps.isEmpty();
        });
    }

    private String requestIdentityKey(HttpServletRequest request) {
        String path = request.getRequestURI();
        if (path.startsWith("/v1/attestation/")
                || path.startsWith("/v1/session/")
                || path.startsWith("/admin/")) {
            return "ip:" + clientIp(request);
        }
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
