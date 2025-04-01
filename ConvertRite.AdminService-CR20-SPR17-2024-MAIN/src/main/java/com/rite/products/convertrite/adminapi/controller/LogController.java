package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.service.LogService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@RestController
@RequestMapping("/api/convertriteadmin")
@Slf4j
public class LogController {

    @Value("${logging.file.name}")
    private String logFilePath;

    @Autowired
    LogService crLogService;

    @GetMapping("/logfile")
    @ResponseBody
    public void viewLogs(@RequestParam(required = false) String date, HttpServletResponse response) throws Exception {
        Path logPath;
        String logFileName;

        if (date != null) {
            logFileName = logFilePath + "." + date + ".0.gz";
        } else {
            logFileName = logFilePath;
        }

        logPath = Paths.get(logFileName).toAbsolutePath();
        log.info("Fetching log file from path: {}", logPath);

        if (!Files.exists(logPath)) {
            throw new IllegalArgumentException("Log file not found for the specified date.");
        }

        if (logFileName.endsWith(".gz")) {
            crLogService.convertDecompressedLogFileToString(logPath, response);
        } else {
            crLogService.convertLogFileToString(logPath, response);
        }
    }

}
