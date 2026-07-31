package ai.digitalmercenaries.ridehorizon.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;

import static org.junit.jupiter.api.Assertions.assertEquals;

class RateLimitFilterPrivacyTest {
    @Test
    void removesInactiveIdentityAfterRateLimitWindow() throws Exception {
        MutableClock clock = new MutableClock(Instant.parse("2026-07-18T00:00:00Z"));
        RateLimitFilter filter = new RateLimitFilter(properties(), clock);

        filter.doFilter(request("device-one"), new MockHttpServletResponse(), new MockFilterChain());
        assertEquals(1, filter.trackedIdentityCount());

        clock.now = clock.now.plusSeconds(61);
        filter.purgeExpiredIdentities();

        assertEquals(0, filter.trackedIdentityCount());
    }

    private static MockHttpServletRequest request(String deviceId) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/v1/fact");
        request.addHeader("X-RideHorizon-Device-Id", deviceId);
        return request;
    }

    private static RideHorizonProperties properties() {
        return new RideHorizonProperties(
                "", "", 30, false,
                "", "",
                false, "", 60,
                "", "",
                "", "", "", "",
                300, 3600, 900,
                180, 120_000, 20, 12_000, 2_000, 250_000,
                30, 24, 3,
                60000, 21600000
        );
    }

    private static final class MutableClock extends Clock {
        private Instant now;

        private MutableClock(Instant now) {
            this.now = now;
        }

        @Override
        public ZoneId getZone() {
            return ZoneId.of("UTC");
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
