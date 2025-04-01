package com.rite.products.convertrite.adminapi;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@OpenAPIDefinition(servers = {@Server(url = "/", description = "Default Server URL")})

@SpringBootApplication
@EnableScheduling
@EnableAsync
public class AdminApiApplication {

	@Value("${cors.allowed-origins}")
	private String allowedOrigins;

	@Value("${cors.allowed-headers}")
	private String allowedHeaders;

	@Value("${cors.allowed-methods}")
	private String allowedMethods;

	public static void main(String[] args) {
		SpringApplication.run(AdminApiApplication.class, args);
	}

	@Bean
	public WebMvcConfigurer corsConfigurer() {
		return new WebMvcConfigurer() {
			@Override
			public void addCorsMappings(CorsRegistry registry) {
				registry.addMapping("/**").allowedMethods(allowedMethods).allowedHeaders(allowedHeaders).allowedOrigins(allowedOrigins);
			}
		};
	}
}
