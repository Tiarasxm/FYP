import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class WearableDevicesPage extends StatefulWidget {
  const WearableDevicesPage({super.key});

  @override
  State<WearableDevicesPage> createState() => _WearableDevicesPageState();
}

class _WearableDevicesPageState extends State<WearableDevicesPage> {
  bool isLoading = true;
  String? updatingProvider;

  final SupabaseClient supabase = Supabase.instance.client;

  final Map<String, bool> connections = {
    'motion_fitness': false,
    'google_fit': false,
    'fitbit': false,
  };

  final List<_DeviceConfig> devices = const [
    _DeviceConfig(
      provider: 'motion_fitness',
      title: 'Motion & Fitness Activity',
      subtitle: 'Use phone motion data for activity tracking.',
      icon: Icons.directions_run,
    ),
    _DeviceConfig(
      provider: 'google_fit',
      title: 'Google Fit / Health Connect',
      subtitle: 'Connect Google fitness data or Android Health Connect.',
      icon: Icons.health_and_safety_outlined,
    ),
    _DeviceConfig(
      provider: 'fitbit',
      title: 'Fitbit',
      subtitle: 'Connect your Fitbit account for fitness data.',
      icon: Icons.watch_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final response = await supabase
          .from('wearable_connections')
          .select('provider, is_connected')
          .eq('profile_id', userId);

      final rows = List<Map<String, dynamic>>.from(response as List);

      final loaded = <String, bool>{
        'motion_fitness': false,
        'google_fit': false,
        'fitbit': false,
      };

      for (final row in rows) {
        final provider = row['provider']?.toString();

        if (provider == null || !loaded.containsKey(provider)) {
          continue;
        }

        loaded[provider] = row['is_connected'] == true;
      }

      if (!mounted) return;

      setState(() {
        connections
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      _showMessage('Failed to load wearable devices: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<bool> _confirmDeviceAction({
    required _DeviceConfig device,
    required bool shouldConnect,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            shouldConnect ? 'Connect ${device.title}?' : 'Disconnect?',
          ),
          content: Text(
            shouldConnect
                ? 'Do you want to connect ${device.title} to your account?'
                : 'Do you want to disconnect ${device.title} from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(shouldConnect ? 'Connect' : 'Disconnect'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _toggleConnection(
    _DeviceConfig device,
    bool shouldConnect,
  ) async {
    if (updatingProvider != null) return;

    final confirmed = await _confirmDeviceAction(
      device: device,
      shouldConnect: shouldConnect,
    );

    if (!confirmed) return;

    setState(() {
      updatingProvider = device.provider;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final now = DateTime.now().toUtc().toIso8601String();

      await supabase.from('wearable_connections').upsert(
        {
          'profile_id': userId,
          'provider': device.provider,
          'is_connected': shouldConnect,
          'connected_at': shouldConnect ? now : null,
          'disconnected_at': shouldConnect ? null : now,
          'updated_at': now,
        },
        onConflict: 'profile_id,provider',
      );

      if (!mounted) return;

      setState(() {
        connections[device.provider] = shouldConnect;
      });

      if (shouldConnect) {
        if (device.provider == 'fitbit' || device.provider == 'google_fit') {
          _showMessage(
            '${device.title} connection saved. OAuth data sync can be added next.',
          );
        } else {
          _showMessage('${device.title} connected.');
        }
      } else {
        _showMessage('${device.title} disconnected.');
      }
    } catch (error) {
      _showMessage('Failed to update device: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          updatingProvider = null;
        });
      }
    }
  }

  bool _isConnected(String provider) {
    return connections[provider] == true;
  }

  bool _isUpdating(String provider) {
    return updatingProvider == provider;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadConnections,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  children: [
                    Row(
                      children: [
                        _CircleBackButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "Wearable Devices",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Connect devices or fitness services to sync activity data.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    for (final device in devices) ...[
                      _DeviceConnectionCard(
                        device: device,
                        value: _isConnected(device.provider),
                        isUpdating: _isUpdating(device.provider),
                        onChanged: (value) {
                          _toggleConnection(device, value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),

                    _infoCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Note: Google Fit / Fitbit data sync needs external authorization. '
        'This page now saves connection status first.',
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DeviceConfig {
  final String provider;
  final String title;
  final String subtitle;
  final IconData icon;

  const _DeviceConfig({
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _DeviceConnectionCard extends StatelessWidget {
  final _DeviceConfig device;
  final bool value;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  const _DeviceConnectionCard({
    required this.device,
    required this.value,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FC),
        borderRadius: BorderRadius.circular(18),
        border: value
            ? Border.all(
                color: AppColors.primary,
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFE6E0FF) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              device.icon,
              size: 20,
              color: value ? AppColors.primary : AppColors.textSecondary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  device.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: value ? Colors.green : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (isUpdating)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CircleBackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FC),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}