package ai.dml.motoguide.factproxy;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class FactSanitizerTest {

    @Test
    void sanitizeTrimsQuotesAndNewlines() {
        assertEquals(
                "Known for its wool trade.",
                FactSanitizer.sanitize("\"Known for its wool trade.\n\"")
        );
    }

    @Test
    void sanitizeRejectsQuestions() {
        assertNull(FactSanitizer.sanitize("Did you know Stroud has canals?"));
    }

    @Test
    void sanitizeRejectsInvitationsAndRouteAdvice() {
        assertNull(FactSanitizer.sanitize("You should visit the old market square."));
        assertNull(FactSanitizer.sanitize("Take the right turn at the junction."));
    }

    @Test
    void sanitizeRejectsExcessSentencesInShortMode() {
        assertNull(FactSanitizer.sanitize(
                "Stroud is in Gloucestershire. It is famous for wool. There is more history too. " +
                        "Another note for this place. Streets changed in recent years. It is still a market town. " +
                        "Riders pass a lot of green lanes around it.",
                FactMode.SHORT_FACTS
        ));
    }

    @Test
    void sanitizeRejectsExcessSentencesInLongMode() {
        assertNull(FactSanitizer.sanitize(
                "Stroud is in Gloucestershire. It is famous for wool. It has deep history. " +
                        "That town shaped trade. It still hosts markets. Another local note remains. " +
                        "The hills can influence local weather. Its rail links were important historically. " +
                        "Riders can cross the bridge on the A419.",
                FactMode.LONG_FACTS
        ));
    }

    @Test
    void sanitizeTruncatesLongFacts() {
        String longFact = "a".repeat(1000);
        assertEquals(700, FactSanitizer.sanitize(longFact).length());
    }

    @Test
    void sanitizeAllowsLongFactsWithinLongModeBound() {
        String longFact = "a".repeat(900);
        assertEquals(900, FactSanitizer.sanitize(longFact, FactMode.LONG_FACTS).length());
    }
}
