CMD /K npm i -g firebase-tools
CMD /K dart pub global activate melos 1.0.0-dev.10
CMD /K dart pub global activate --source=path . --executable=flutterfire
melos bootstrap