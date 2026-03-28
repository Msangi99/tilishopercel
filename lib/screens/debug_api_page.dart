import 'package:flutter/material.dart';
import 'package:t_percel/services/api_service.dart';

class DebugApiPage extends StatefulWidget {
  const DebugApiPage({super.key});

  @override
  State<DebugApiPage> createState() => _DebugApiPageState();
}

class _DebugApiPageState extends State<DebugApiPage> {
  String _busesResult = '';
  String _routesResult = '';
  bool _isLoading = false;

  Future<void> _testBuses() async {
    setState(() {
      _isLoading = true;
      _busesResult = 'Loading buses...';
    });

    try {
      final buses = await ApiService.getBuses();
      setState(() {
        _busesResult = 'SUCCESS!\n\nBuses count: ${buses.length}\n\nFirst bus:\n${buses.isNotEmpty ? buses.first.toString() : "No buses"}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _busesResult = 'ERROR: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testRoutes() async {
    setState(() {
      _isLoading = true;
      _routesResult = 'Loading routes...';
    });

    try {
      final routes = await ApiService.getRoutes();
      setState(() {
        _routesResult = 'SUCCESS!\n\nRoutes count: ${routes.length}\n\nFirst route:\n${routes.isNotEmpty ? routes.first.toString() : "No routes"}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _routesResult = 'ERROR: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await _testBuses();
    await _testRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refreshAll,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: Colors.blue.shade800,
            onRefresh: _refreshAll,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                children: [
                  // Test Buses Button
                  ElevatedButton.icon(
                    onPressed: _testBuses,
                    icon: const Icon(Icons.bus_alert),
                    label: const Text('Test Get Buses API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Test Routes Button
                  ElevatedButton.icon(
                    onPressed: _testRoutes,
                    icon: const Icon(Icons.route),
                    label: const Text('Test Get Routes API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Results
                  if (_busesResult.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _busesResult.startsWith('SUCCESS') 
                            ? Colors.green.shade50 
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _busesResult.startsWith('SUCCESS') 
                              ? Colors.green 
                              : Colors.red,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUSES RESULT:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(_busesResult),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_routesResult.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _routesResult.startsWith('SUCCESS') 
                            ? Colors.green.shade50 
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _routesResult.startsWith('SUCCESS') 
                              ? Colors.green 
                              : Colors.red,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUTES RESULT:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(_routesResult),
                        ],
                      ),
                    ),
                ],
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
