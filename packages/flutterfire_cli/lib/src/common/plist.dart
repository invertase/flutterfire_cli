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
 */

import 'package:xml/xml.dart' as xml;

Object? parsePlist(String source) {
  final document = xml.XmlDocument.parse(source);
  return _parseElement(
    document.rootElement.childElements.first,
  );
}

Object? _parseElement(xml.XmlElement element) {
  switch (element.name.local) {
    case 'true':
      return true;
    case 'false':
      return false;
    case 'string':
      return element.innerText;
    case 'dict':
      return _parseDict(element);
    // 'array', 'real','integer' & 'date' are missing,
    // but we don't need then for our use case.
  }
  throw UnsupportedError('Unsupported plist element: ${element.name.local}');
}

Map<String, Object?> _parseDict(xml.XmlElement element) {
  final childElements = element.childElements;
  final keys = childElements
      .where((element) => element.name.local == 'key')
      .map((element) => element.innerText);
  final values = childElements
      .where((element) => element.name.local != 'key')
      .map(_parseElement);
  return Map<String, Object?>.fromIterables(keys, values);
}
