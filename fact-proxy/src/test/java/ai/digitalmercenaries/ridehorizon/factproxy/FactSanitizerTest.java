package ai.digitalmercenaries.ridehorizon.factproxy;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

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
                "The valley shaped the town. Wool powered its mills. Canals carried their cloth. " +
                        "Markets linked local producers. Stone buildings preserve that history. " +
                        "Modern workshops continue the tradition.",
                FactMode.LONG_FACTS
        ));
    }

    @Test
    void sanitizeAllowsFiveSentencesInLongMode() {
        String fact = "The valley shaped the town. Wool powered its mills. Canals carried their cloth. " +
                "Markets linked local producers. Stone buildings preserve that history.";

        assertEquals(fact, FactSanitizer.sanitize(fact, FactMode.LONG_FACTS));
    }

    @Test
    void longFactsTargetCoherent110To130WordsWithFiveSentenceBound() {
        String prompt = FactMode.LONG_FACTS.defaultPrompt();

        assertTrue(prompt.contains("110 to 130 words"));
        assertTrue(prompt.contains("coherent"));
        assertTrue(prompt.contains("connected sentences"));
        assertTrue(prompt.contains("trivia list"));
        assertTrue(prompt.contains("repeat"));
        assertEquals(5, FactMode.LONG_FACTS.maxSentences());
    }

    @Test
    void shortFactsPromptAndBoundsRemainUnchanged() {
        String prompt = FactMode.SHORT_FACTS.defaultPrompt();

        assertTrue(prompt.contains("35 to 45 words"));
        assertFalse(prompt.contains("110 to 130 words"));
        assertEquals(2, FactMode.SHORT_FACTS.maxSentences());
        assertEquals(1100, FactMode.SHORT_FACTS.maxFactLength());
    }

    @Test
    void sanitizeTruncatesLongFacts() {
        String longFact = "a".repeat(1_200);
        assertEquals(1100, FactSanitizer.sanitize(longFact).length());
    }

    @Test
    void sanitizeAllowsLongFactsWithinLongModeBound() {
        String longFact = "a".repeat(1500);
        assertEquals(1500, FactSanitizer.sanitize(longFact, FactMode.LONG_FACTS).length());
    }

    @Test
    void sanitizeAllowsRiderContextTermsThatWereOverfiltered() {
        assertEquals(
                "Motorcycle routes followed the old rail corridor through the valley.",
                FactSanitizer.sanitize("Motorcycle routes followed the old rail corridor through the valley.")
        );
    }
}
