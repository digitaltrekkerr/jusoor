package com.digitaltrekkerr.jusoor

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Locks `stripMarkdownForClipboard` (TranslationOverlayService.kt) to the
 * Dart canonical contract implemented by `toPlainText` in
 * `packages/markdown_renderer/lib/src/utils/markdown_stripper.dart`.
 *
 * Every `expected` value below was captured from the real Dart
 * `toPlainText` output for the same input, so these tests prove
 * cross-language convergence for the locked contract cases.
 *
 * Idempotency: re-stripping an already-stripped string must leave it
 * unchanged, and a second strip of any input must equal the first.
 */
class StripMarkdownTest {

    private val strip: (String) -> String =
        TranslationOverlayService.Companion::stripMarkdownForClipboard

    /** (markdown input, Dart toPlainText output) pairs — the locked contract. */
    private val contractCases: Array<Pair<String, String>> = arrayOf(
        "**hello**" to "hello",
        "*hello*" to "hello",
        "_hello_" to "hello",
        "use `print()` here" to "use print() here",
        "`a` and `b` and `c`" to "a and b and c",
        "```dart\nvoid main() {}\n```" to "void main() {}",
        "Before:\n```dart\nvoid main() {}\n```\nAfter." to "Before: void main() {} After.",
        "```\nconsole.log(\"x\")\n```" to "console.log(\"x\")",
        "```text\na `b` c\n```" to "a b c",
        "```text\n*a*\n```" to "a",
        "***bold italic***" to "bold italic",
        "**bold *italic* text**" to "bold italic text",
        "**bold _italic_ text**" to "bold italic text",
        "_nested **bold** inside_" to "nested bold inside",
        "x **bold *italic* text** y" to "x bold italic text y",
        "a   b\n\nc" to "a b c",
        "line1\nline2" to "line1 line2",
        "  hello  " to "hello",
        "# Title" to "Title",
        "## Subtitle" to "Subtitle",
        "[link](https://example.com)" to "link",
        "![alt](img.png)" to "alt",
        "- item\n- other" to "item other",
        "1. first\n2. second" to "first second",
        "> quote line" to "quote line",
        "~~strike~~" to "strike",
        "**مرحبا** بالعالم" to "مرحبا بالعالم",
        "Just plain text." to "Just plain text.",
        "5 * 3" to "5 * 3",
        "a__b__c" to "a__b__c",
        "a_b_c" to "a_b_c",
        "Text **with** nested `code` *inside*." to "Text with nested code inside.",
        "nested `code **bold**` inline" to "nested code bold inline",
        "" to "",
    )

    @Test
    fun stripMatchesDartContract() {
        for ((input, expected) in contractCases) {
            assertEquals("strip($input) should equal Dart toPlainText output", expected, strip(input))
        }
    }

    @Test
    fun stripIsIdempotent() {
        for ((input, expected) in contractCases) {
            val once = strip(input)
            val twice = strip(once)
            assertEquals("strip(strip($input)) should equal strip($input)", once, twice)
            assertEquals("strip of an already-stripped string should be a no-op", expected, strip(expected))
        }
    }

    @Test
    fun stripPreservesFencedBlockContent() {
        // Regression: the old implementation replaced fenced blocks with a
        // single space, dropping the code entirely.
        assertEquals("void main() {}", strip("```dart\nvoid main() {}\n```"))
        assertEquals("int x = 1; copy", strip("```java\nint x = 1;\n```\ncopy"))
    }

    @Test
    fun stripKeepsSingleAsteriskArithmetic() {
        assertEquals("5 * 3", strip("5 * 3"))
        assertEquals("a * b and c * d", strip("a * b and c * d"))
    }
}