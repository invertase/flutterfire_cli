/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

// Minimal, dependency-free replacement for the unmaintained `interact`
// package. Only implements the interactive primitives flutterfire_cli
// actually uses: Confirm, Select, MultiSelect, Input (+ validation), and
// a text Spinner. No dependency on dart_console, so no transitive `intl`
// version constraint.

import 'dart:async';
import 'dart:io';

/// Thrown by an input validator to reject a value with a message.
class ValidationError implements Exception {
  ValidationError(this.message);
  final String message;

  @override
  String toString() => message;
}

const _esc = '\x1b';
const _up = '$_esc[A';
const _clearLine = '\x1b[2K\r';

bool get _supportsRawMode {
  try {
    return stdin.hasTerminal;
  } catch (_) {
    return false;
  }
}

/// Reads a single raw key press. Returns the arrow key name
/// ('up'/'down'/'left'/'right'), 'enter', 'space', 'backspace', or the
/// literal character.
String? _readKey() {
  final byte = stdin.readByteSync();
  if (byte == -1) return null;
  if (byte == 13 || byte == 10) return 'enter';
  if (byte == 32) return 'space';
  if (byte == 127 || byte == 8) return 'backspace';
  if (byte == 3) {
    // Ctrl+C
    exit(130);
  }
  if (byte == _esc.codeUnitAt(0)) {
    final next1 = stdin.readByteSync();
    final next2 = stdin.readByteSync();
    if (next1 == 91) {
      switch (next2) {
        case 65:
          return 'up';
        case 66:
          return 'down';
        case 67:
          return 'right';
        case 68:
          return 'left';
      }
    }
    return null;
  }
  return String.fromCharCode(byte);
}

T _withRawMode<T>(T Function() body) {
  if (!_supportsRawMode) return body();
  final echoWas = stdin.echoMode;
  final lineWas = stdin.lineMode;
  stdin.echoMode = false;
  stdin.lineMode = false;
  try {
    return body();
  } finally {
    stdin.echoMode = echoWas;
    stdin.lineMode = lineWas;
  }
}

/// Yes/no prompt. Accepts y/n/enter (enter = defaultValue).
bool promptConfirm(String prompt, {bool defaultValue = true}) {
  final hint = defaultValue ? 'Y/n' : 'y/N';
  stdout.write('$prompt ($hint) ');
  final line = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  if (line.isEmpty) return defaultValue;
  return line == 'y' || line == 'yes';
}

/// Arrow-key single-select. Falls back to numbered input on non-interactive
/// terminals (e.g. CI, piped input).
int promptSelectIndex(
  String prompt,
  List<String> choices, {
  int initialIndex = 0,
}) {
  if (!_supportsRawMode) {
    return _fallbackNumberedSelect(prompt, choices, initialIndex);
  }

  var index = initialIndex;
  void render({bool first = false}) {
    if (!first) {
      stdout.write(_up * choices.length);
    }
    for (var i = 0; i < choices.length; i++) {
      stdout.write(_clearLine);
      final pointer = i == index ? '❯ ' : '  ';
      stdout.writeln('$pointer${choices[i]}');
    }
  }

  return _withRawMode(() {
    stdout.writeln(prompt);
    render(first: true);
    while (true) {
      final key = _readKey();
      if (key == 'up') {
        index = (index - 1 + choices.length) % choices.length;
        render();
      } else if (key == 'down') {
        index = (index + 1) % choices.length;
        render();
      } else if (key == 'enter') {
        return index;
      }
    }
  });
}

int _fallbackNumberedSelect(
  String prompt,
  List<String> choices,
  int initialIndex,
) {
  stdout.writeln(prompt);
  for (var i = 0; i < choices.length; i++) {
    stdout.writeln('  ${i + 1}) ${choices[i]}');
  }
  while (true) {
    stdout.write('Enter a number (default ${initialIndex + 1}): ');
    final line = stdin.readLineSync()?.trim() ?? '';
    if (line.isEmpty) return initialIndex;
    final n = int.tryParse(line);
    if (n != null && n >= 1 && n <= choices.length) return n - 1;
    stdout.writeln('Invalid choice.');
  }
}

/// Space-toggle multi-select. Falls back to comma-separated numbers on
/// non-interactive terminals.
List<int> promptMultiSelectIndices(
  String prompt,
  List<String> choices, {
  List<bool>? defaultSelection,
}) {
  final selected = List<bool>.from(
    defaultSelection ?? List.filled(choices.length, false),
  );

  if (!_supportsRawMode) {
    return _fallbackNumberedMultiSelect(prompt, choices, selected);
  }

  var cursor = 0;
  void render({bool first = false}) {
    if (!first) {
      stdout.write(_up * choices.length);
    }
    for (var i = 0; i < choices.length; i++) {
      stdout.write(_clearLine);
      final pointer = i == cursor ? '❯ ' : '  ';
      final box = selected[i] ? '[x]' : '[ ]';
      stdout.writeln('$pointer$box ${choices[i]}');
    }
  }

  return _withRawMode(() {
    stdout.writeln('$prompt (space to toggle, enter to confirm)');
    render(first: true);
    while (true) {
      final key = _readKey();
      if (key == 'up') {
        cursor = (cursor - 1 + choices.length) % choices.length;
        render();
      } else if (key == 'down') {
        cursor = (cursor + 1) % choices.length;
        render();
      } else if (key == 'space') {
        selected[cursor] = !selected[cursor];
        render();
      } else if (key == 'enter') {
        return [
          for (var i = 0; i < selected.length; i++)
            if (selected[i]) i,
        ];
      }
    }
  });
}

List<int> _fallbackNumberedMultiSelect(
  String prompt,
  List<String> choices,
  List<bool> defaults,
) {
  stdout.writeln(prompt);
  for (var i = 0; i < choices.length; i++) {
    stdout.writeln('  ${i + 1}) ${choices[i]}');
  }
  final preselected = [
    for (var i = 0; i < defaults.length; i++)
      if (defaults[i]) i,
  ];
  stdout.write(
    'Enter comma-separated numbers'
    '${preselected.isNotEmpty ? ' (default: ${preselected.map((i) => i + 1).join(',')})' : ''}: ',
  );
  final line = stdin.readLineSync()?.trim() ?? '';
  if (line.isEmpty) return preselected;
  final result = <int>[];
  for (final part in line.split(',')) {
    final n = int.tryParse(part.trim());
    if (n != null && n >= 1 && n <= choices.length) {
      result.add(n - 1);
    }
  }
  return result;
}

/// Free-text input with optional default value and validator. The
/// validator may return `false`/`true`, or a [String] error message
/// (or throw [ValidationError]) to reject the input.
String promptText(
  String prompt, {
  String? defaultValue,
  dynamic Function(String)? validator,
}) {
  while (true) {
    final suffix = defaultValue != null ? ' ($defaultValue)' : '';
    stdout.write('$prompt$suffix ');
    final raw = stdin.readLineSync() ?? '';
    final value = raw.isEmpty ? (defaultValue ?? '') : raw;

    if (validator == null) return value;

    try {
      final result = validator(value);
      if (result is bool) {
        if (result) return value;
        stdout.writeln('Invalid input.');
        continue;
      }
      if (result is String) {
        stdout.writeln(result);
        continue;
      }
      return value;
    } on ValidationError catch (e) {
      stdout.writeln(e.message);
    }
  }
}

/// Handle returned by [textSpinner]; call [done] when the operation
/// finishes to stop the animation and print the final message.
class SpinnerHandle {
  SpinnerHandle._(this._timer, this._rightPrompt);

  final Timer? _timer;
  final String Function(bool done) _rightPrompt;
  bool _isDone = false;

  void done() {
    if (_isDone) return;
    _isDone = true;
    _timer?.cancel();
    if (stdout.hasTerminal) {
      stdout.write(_clearLine);
    }
    stdout.writeln(_rightPrompt(true));
  }
}

const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

/// Starts an animated spinner (or a static line if not attached to a
/// terminal, e.g. in CI) and returns a handle; call `.done()` to stop it.
SpinnerHandle textSpinner(String Function(bool done) rightPrompt) {
  if (!stdout.hasTerminal) {
    stdout.writeln(rightPrompt(false));
    return SpinnerHandle._(null, rightPrompt);
  }
  var frame = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
    stdout.write(_clearLine);
    stdout.write('${_frames[frame % _frames.length]} ${rightPrompt(false)}');
    frame++;
  });
  return SpinnerHandle._(timer, rightPrompt);
}
