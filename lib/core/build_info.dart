/// Set by CI with --dart-define=BUILD=<run number>.
const String kBuild = String.fromEnvironment('BUILD', defaultValue: 'dev');
const String kBuildLabel = 'Shipper Deliveric build $kBuild';
