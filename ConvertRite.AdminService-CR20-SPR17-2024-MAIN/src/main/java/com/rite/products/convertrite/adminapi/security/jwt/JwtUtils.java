package com.rite.products.convertrite.adminapi.security.jwt;

import com.auth0.jwk.Jwk;
import com.auth0.jwk.JwkException;
import com.auth0.jwk.JwkProvider;
import com.auth0.jwk.UrlJwkProvider;
import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.SignatureVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.rite.products.convertrite.adminapi.service.AuthUserDetailsImpl;
import io.jsonwebtoken.*;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.security.interfaces.RSAPublicKey;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Component
public class JwtUtils {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.expirytimems}")
    private int jwtExpiration;

    @Value("${spring.security.oauth2.resourceserver.jwt.jwks-uri}")
    private String jwtJwksUri;

    public String generateJwtToken(Authentication authentication) {

        AuthUserDetailsImpl userPrincipal = (AuthUserDetailsImpl) authentication.getPrincipal();

        // Extract roles from the Authentication object
        String roles = authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.joining(","));
        log.info("roles-----> {} ", roles);
        return Jwts.builder()
                .setSubject(userPrincipal.getUsername())
                .claim("roles", roles) // Add roles as a claim
                .setIssuedAt(new Date())
                .setExpiration(new Date((new Date()).getTime() + jwtExpiration))
                .signWith(key(), SignatureAlgorithm.HS256)
                .compact();
    }

    public String generateJwtToken(AuthUserDetailsImpl userDetails) {
        return Jwts.builder()
                .setSubject((userDetails.getUsername()))
                .setIssuedAt(new Date())
                .setExpiration(new Date((new Date()).getTime() + jwtExpiration))
                .signWith(key(), SignatureAlgorithm.HS256)
                .compact();
    }

    private Key key() {
        return Keys.hmacShaKeyFor(Decoders.BASE64.decode(jwtSecret));
    }

    public String getUserNameFromJwtToken(String token) {
        return Jwts.parserBuilder().setSigningKey(key()).build()
                .parseClaimsJws(token).getBody().getSubject();
    }

    public boolean validateJwtToken(String authToken) throws Exception {
        try {
            Jwts.parserBuilder().setSigningKey(key()).build().parseClaimsJws(authToken);
            return true;
        } catch (MalformedJwtException e) {
            log.error("Invalid JWT token: {}", e.getMessage());
            throw e;
        } catch (ExpiredJwtException e) {
            log.error("JWT token is expired: {}", e.getMessage());
            throw e;
        } catch (UnsupportedJwtException e) {
            log.error("JWT token is unsupported: {}", e.getMessage());
            throw e;
        } catch (IllegalArgumentException e) {
            log.error("JWT claims string is empty: {}", e.getMessage());
            throw e;
        }
    }

    public boolean isTokenExpired(String token) {
        final Date expiration = Jwts.parser().setSigningKey(key()).parseClaimsJws(token).getBody().getExpiration();
        return expiration.before(new Date());
    }

    public boolean validateOAuthJwtToken(String authToken) {
        try {
            JwkProvider provider = new UrlJwkProvider(jwtJwksUri);
            DecodedJWT decodedJwt = JWT.decode(authToken);
            Jwk jwk = provider.get(decodedJwt.getKeyId());
            Algorithm algorithm = Algorithm.RSA256((RSAPublicKey) jwk.getPublicKey(), null);
            algorithm.verify(decodedJwt);
            if (decodedJwt.getExpiresAt().before(Calendar.getInstance().getTime())) {
                throw new RuntimeException("Expired token!");
            }
            return true;
        } catch (JwkException e) {

        } catch (SignatureVerificationException e) {

        } catch (Exception e) {

        }
        return false;
    }
    public List<String> getRolesFromJwtToken(String token) {
        try {
            Claims claims = Jwts.parserBuilder()
                    .setSigningKey(key())
                    .build()
                    .parseClaimsJws(token)
                    .getBody();

            String roles = claims.get("roles", String.class);
            return Arrays.asList(roles.split(","));
        } catch (SignatureException e) {
            // Handle invalid signature
            throw new RuntimeException("Invalid JWT signature", e);
        } catch (Exception e) {
            // Handle other exceptions
            throw new RuntimeException("Failed to parse JWT token", e);
        }
    }
}
