package com.rite.products.convertrite.adminapi.security.jwt;

import com.auth0.jwt.JWT;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.rite.products.convertrite.adminapi.service.AuthServiceImpl;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.servlet.HandlerExceptionResolver;

import java.io.IOException;
import java.util.Base64;

public class AuthTokenFilter extends OncePerRequestFilter {
    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private AuthServiceImpl authServiceImpl;

    @Autowired
    @Qualifier("handlerExceptionResolver")
    private HandlerExceptionResolver exceptionResolver;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String jwt = parseJwt(request);
            if (jwt != null) {
                DecodedJWT decodedJwt = JWT.decode(jwt);
                String kid = decodedJwt.getKeyId();
                UserDetails userDetails = null;
                boolean validToken = false;
                if (kid != null) { //&& jwtUtils.validateOAuthJwtToken(jwt)
                    //OAuth B2C JWT. Validate it here
                    String jwtPayloadString = decodedJwt.getPayload();
                    Base64.Decoder decoder = Base64.getUrlDecoder();
                    String payload = new String(decoder.decode(jwtPayloadString));

                    JSONObject jwtPayload = new JSONObject(payload);
                    JSONArray emails = jwtPayload.getJSONArray("emails");
                    String email = emails.getString(0);
                    userDetails = authServiceImpl.loadUserByEmail(email);

                    validToken = true;
                } else if (kid == null && jwtUtils.validateJwtToken(jwt)) {
                    //Static JWT
                    String username = jwtUtils.getUserNameFromJwtToken(jwt);

                    userDetails = authServiceImpl.loadUserByUsername(username);
                    validToken = true;
                }
                if (validToken && (userDetails != null)) {
                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(userDetails, null,
                            userDetails.getAuthorities());
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }
        } catch (Exception e) {
            exceptionResolver.resolveException(request, response, null, e);
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String parseJwt(HttpServletRequest request) {
        String headerAuth = request.getHeader("Authorization");

        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            return headerAuth.substring(7, headerAuth.length());
        }

        return null;
    }
}
