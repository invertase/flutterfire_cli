#!/bin/bash
npm i -g firebase-tools
dart pub global activate melos 1.0.0-dev.10
dart pub global activate --source="path" . --executable="flutterfire"
melos bootstrap
