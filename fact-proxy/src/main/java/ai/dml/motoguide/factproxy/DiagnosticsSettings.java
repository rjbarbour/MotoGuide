package ai.dml.motoguide.factproxy;

import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicBoolean;

@Component
public class DiagnosticsSettings {
    private final AtomicBoolean enabled;

    public DiagnosticsSettings(MotoGuideProperties properties) {
        this.enabled = new AtomicBoolean(properties.diagnosticsEnabled());
    }

    public boolean enabled() {
        return enabled.get();
    }

    public boolean setEnabled(boolean enabled) {
        this.enabled.set(enabled);
        return enabled;
    }
}
