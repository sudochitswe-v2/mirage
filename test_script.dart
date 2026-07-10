import 'dart:io';

void main() async {
  print('Running pkexec test...');
  final result = await Process.run('pkexec', ['sh', '-c', 'echo "test"']);
  print('exitCode: \${result.exitCode}');
  print('stdout: \${result.stdout}');
  print('stderr: \${result.stderr}');
}
