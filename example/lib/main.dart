import 'package:flutter/material.dart';
import 'package:smart_upload_field/media_form_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Upload Field Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  List<SmartUploadValue> _uploadValues = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Upload Field'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modern Upload Experience',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'A single field to handle all your upload needs: images, files, or links.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 40),
              MediaFormField(
                label: 'Single Upload',
                hint: 'Pick an image, file or enter a URL',
                multiple: false,
                onChanged: (values) {
                  setState(() {
                    _uploadValues = values;
                  });
                },
                validator: (values) {
                  if (values == null || values.isEmpty) {
                    return 'Please select or enter something';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              MediaFormField(
                label: 'Multiple Uploads (Max 5)',
                hint: 'Attach multiple items',
                multiple: true,
                maxItems: 5,
                onChanged: (values) {
                  print('Selected: ${values.length} items');
                },
              ),
              const SizedBox(height: 40),
              if (_uploadValues.isNotEmpty) ...[
                const Text(
                  'Last Selection:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _uploadValues
                        .map((v) => Text(v.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Form Validated!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit Form'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
