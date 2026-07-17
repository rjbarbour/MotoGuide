package ai.digitalmercenaries.ridehorizon.factproxy;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;
import java.net.URI;

@Configuration
public class DataSourceConfig {

    @Bean
    @Primary
    DataSource dataSource(DataSourceProperties properties, Environment environment) {
        String databaseUrl = environment.getProperty("DATABASE_URL");
        if (databaseUrl == null || databaseUrl.isBlank()) {
            return properties.initializeDataSourceBuilder().build();
        }

        URI uri = URI.create(databaseUrl);
        if (!"postgres".equals(uri.getScheme()) && !"postgresql".equals(uri.getScheme())) {
            throw new IllegalStateException("DATABASE_URL must use the postgres scheme");
        }
        String userInfo = uri.getUserInfo();
        String[] credentials = userInfo == null ? new String[0] : userInfo.split(":", 2);
        if (credentials.length != 2) {
            throw new IllegalStateException("DATABASE_URL must contain database credentials");
        }

        String query = uri.getRawQuery();
        String jdbcUrl = "jdbc:postgresql://" + uri.getHost() + ":" + effectivePort(uri)
                + uri.getRawPath() + (query == null ? "" : "?" + query);

        HikariDataSource dataSource = new HikariDataSource();
        dataSource.setJdbcUrl(jdbcUrl);
        dataSource.setUsername(credentials[0]);
        dataSource.setPassword(credentials[1]);
        dataSource.setMaximumPoolSize(5);
        dataSource.setMinimumIdle(0);
        dataSource.setConnectionTimeout(5_000);
        return dataSource;
    }

    private static int effectivePort(URI uri) {
        return uri.getPort() > 0 ? uri.getPort() : 5432;
    }
}
