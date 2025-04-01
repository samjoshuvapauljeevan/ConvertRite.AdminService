package com.rite.products.convertrite.adminapi.utils;

import java.security.SecureRandom;

public class PasswordUtils {
    private static final String LOWER_CASES = "abcdefghijklmnopqrstuvwxyz";
    private static final String UPPER_CASES = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String DIGITS = "0123456789";
    private static final String ALL_CHARS = LOWER_CASES + UPPER_CASES + DIGITS;

    private static final SecureRandom random = new SecureRandom();

    public static String generatePassword() {
        int length = 8;
        StringBuilder password = new StringBuilder(length);

        // Ensure at least one character of each type is used
        password.append(LOWER_CASES.charAt(random.nextInt(LOWER_CASES.length())));
        password.append(UPPER_CASES.charAt(random.nextInt(UPPER_CASES.length())));
        password.append(DIGITS.charAt(random.nextInt(DIGITS.length())));

        // Fill the rest of the password
        for (int i = 3; i < length; i++) {
            password.append(ALL_CHARS.charAt(random.nextInt(ALL_CHARS.length())));
        }

        // Shuffle to avoid predictable order
        char[] pwdArray = password.toString().toCharArray();
        for (int i = pwdArray.length - 1; i > 0; i--) {
            int index = random.nextInt(i + 1);
            char temp = pwdArray[index];
            pwdArray[index] = pwdArray[i];
            pwdArray[i] = temp;
        }

        return new String(pwdArray);
    }
    public static boolean isValid(String value) {
        if (value == null) {
            return false;
        }
        return value.matches("^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$");
    }
}

