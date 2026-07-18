package ai.digitalmercenaries.ridehorizon.factproxy;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class FactProxyApplication {
    public static void main(String[] args) {
        SpringApplication.run(FactProxyApplication.class, args);
    }
}
