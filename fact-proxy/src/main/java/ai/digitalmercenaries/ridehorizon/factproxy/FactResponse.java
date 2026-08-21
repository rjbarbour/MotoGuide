package ai.digitalmercenaries.ridehorizon.factproxy;

import java.util.List;

// Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
public record FactResponse(String fact, List<FactSource> sources) {
    public FactResponse {
        sources = List.copyOf(sources);
    }
}
