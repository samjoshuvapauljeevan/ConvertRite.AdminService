package com.rite.products.convertrite.adminapi.service;


import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.GZIPInputStream;

@Service
@Slf4j
public class LogService {

    public void convertLogFileToString(Path logPath, HttpServletResponse response) throws IOException {
        response.setContentType("text/plain");
        try (PrintWriter writer = response.getWriter();
             BufferedReader reader = new BufferedReader(new InputStreamReader(Files.newInputStream(logPath)))) {

            reader.lines().forEach(writer::println);

        } catch (IOException e) {
            log.error("Error reading log file: {}", logPath, e);
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error reading log file.");
        }
    }

    public void convertDecompressedLogFileToString(Path logPath, HttpServletResponse response) throws IOException {
        response.setContentType("text/plain");
        try (PrintWriter writer = response.getWriter();
             BufferedReader reader = new BufferedReader(new InputStreamReader(new GZIPInputStream(Files.newInputStream(logPath))))) {

            reader.lines().forEach(writer::println);

        } catch (IOException e) {
            log.error("Error reading compressed log file: {}", logPath, e);
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error reading compressed log file.");
        }
    }
}