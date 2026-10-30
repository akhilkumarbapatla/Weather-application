import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WeatherApp());
}

const bg = Color(0xFF101827);
const panel = Color(0xFF1C293B);
const accent = Color(0xFF58B9F5);

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  bool lightTheme = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather Now',
      theme: ThemeData(
        useMaterial3: true,
        brightness: lightTheme ? Brightness.light : Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: lightTheme ? Brightness.light : Brightness.dark,
        ),
        scaffoldBackgroundColor:
            lightTheme ? const Color(0xFFF1F5F9) : bg,
      ),
      home: AuthGate(
        lightTheme: lightTheme,
        onThemeChanged: (value) => setState(() => lightTheme = value),
      ),
    );
  }
}

// ---------------- AUTHENTICATION ----------------
// Demo-only local authentication. Do not use this for real accounts.
// Use Firebase Authentication for production apps.

class AuthGate extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;

  const AuthGate({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  String? name;
  String? email;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('sessionName');
      email = prefs.getString('sessionEmail');
      loading = false;
    });
  }

  Future<void> _onAuthenticated(String userName, String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionName', userName);
    await prefs.setString('sessionEmail', userEmail);
    if (!mounted) return;
    setState(() {
      name = userName;
      email = userEmail;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionName');
    await prefs.remove('sessionEmail');
    if (!mounted) return;
    setState(() {
      name = null;
      email = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (name != null && email != null) {
      return WeatherHome(
        userName: name!,
        userEmail: email!,
        onLogout: _logout,
        lightTheme: widget.lightTheme,
        onThemeChanged: widget.onThemeChanged,
      );
    }

    return AuthScreen(onAuthenticated: _onAuthenticated);
  }
}

class AuthScreen extends StatefulWidget {
  final Future<void> Function(String, String) onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool isLogin = true;
  bool hidePassword = true;
  bool busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => busy = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getString('demoUsers');
      final Map<String, dynamic> accounts =
          users == null ? {} : jsonDecode(users);

      final email = _email.text.trim().toLowerCase();
      final password = _password.text;

      if (isLogin) {
        if (!accounts.containsKey(email) ||
            accounts[email]['password'] != password) {
          throw Exception('Account not found or password is incorrect.');
        }
        await widget.onAuthenticated(accounts[email]['name'], email);
      } else {
        if (accounts.containsKey(email)) {
          throw Exception('An account with this email already exists.');
        }
        final name = _name.text.trim();
        accounts[email] = {'name': name, 'password': password};
        await prefs.setString('demoUsers', jsonEncode(accounts));
        await widget.onAuthenticated(name, email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102D50), bg, Color(0xFF172B46)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.cloud, size: 88, color: accent),
                    const SizedBox(height: 12),
                    const Text(
                      'WEATHER NOW',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your weather, anytime, anywhere',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 38),
                    Text(
                      isLogin ? 'Welcome Back!' : 'Create Account',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: _name,
                        decoration: _decoration('Full name', Icons.person),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 15),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('Email address', Icons.email),
                      validator: (v) {
                        if (v == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _password,
                      obscureText: hidePassword,
                      decoration: _decoration('Password', Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: busy
                            ? const CircularProgressIndicator()
                            : Text(
                                isLogin ? 'LOGIN' : 'SIGN UP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? "Don't have an account? Sign up"
                            : 'Already have an account? Login',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Demo authentication • Open-Meteo weather data',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- DATA MODELS ----------------

class City {
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  const City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] ?? 'Unknown',
      country: json['country'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory City.fromStoredJson(String value) =>
      City.fromJson(jsonDecode(value));
}

class WeatherService {
  static Future<List<City>> searchCity(String name) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': name,
        'count': '10',
        'language': 'en',
        'format': 'json',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('City search failed. Try again.');
    }

    final data = jsonDecode(response.body);
    final results = data['results'] as List? ?? [];
    return results.map((e) => City.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> getWeather(
    City city,
    bool fahrenheit,
  ) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': city.latitude.toString(),
        'longitude': city.longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'temperature_unit': fahrenheit ? 'fahrenheit' : 'celsius',
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
        'forecast_days': '7',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Weather service is unavailable. Try again.');
    }
    return jsonDecode(response.body);
  }
}

// ---------------- WEATHER HELPERS ----------------

String weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rainy';
  if (code >= 71 && code <= 77) return 'Snowy';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 85 && code <= 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Cloudy';
}

IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.water_drop_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.grain;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud;
}

String formatHour(String value) {
  final date = DateTime.parse(value);
  final hour = date.hour;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour $suffix';
}

// ---------------- MAIN WEATHER APP ----------------

class WeatherHome extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;

  const WeatherHome({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.lightTheme,
    required this.onThemeChanged,
  });

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  City? selectedCity;
  Map<String, dynamic>? weather;
  bool loading = false;
  bool fahrenheit = false;
  int selectedTab = 0;
  String? error;
  List<City> savedCities = [];
  List<City> recentCities = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('savedCities') ?? [];
    final recent = prefs.getStringList('recentCities') ?? [];
    if (!mounted) return;
    setState(() {
      fahrenheit = prefs.getBool('fahrenheit') ?? false;
      savedCities = saved.map(City.fromStoredJson).toList();
      recentCities = recent.map(City.fromStoredJson).toList();
    });
    await searchAndLoad('Guntur');
  }

  Future<void> _persistCities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'savedCities',
      savedCities.map((c) => jsonEncode(c.toJson())).toList(),
    );
    await prefs.setStringList(
      'recentCities',
      recentCities.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> searchAndLoad(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final matches = await WeatherService.searchCity(query.trim());
      if (matches.isEmpty) throw Exception('No matching city found.');

      if (matches.length == 1) {
        await _loadCity(matches.first);
      } else {
        if (!mounted) return;
        final chosen = await showModalBottomSheet<City>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Choose a city',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ...matches.map(
                  (city) => ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(city.name),
                    subtitle: Text(city.country),
                    onTap: () => Navigator.pop(sheetContext, city),
                  ),
                ),
              ],
            ),
          ),
        );
        if (chosen != null) await _loadCity(chosen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error!)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadCity(City city) async {
    final result = await WeatherService.getWeather(city, fahrenheit);
    if (!mounted) return;

    setState(() {
      selectedCity = city;
      weather = result;
      error = null;
      recentCities.removeWhere(
        (c) => c.latitude == city.latitude && c.longitude == city.longitude,
      );
      recentCities.insert(0, city);
      if (recentCities.length > 8) recentCities.removeLast();
    });
    await _persistCities();
  }

  Future<void> _toggleSaved() async {
    if (selectedCity == null) return;
    final city = selectedCity!;
    final exists = savedCities.any(
      (c) => c.latitude == city.latitude && c.longitude == city.longitude,
    );

    setState(() {
      if (exists) {
        savedCities.removeWhere(
          (c) => c.latitude == city.latitude && c.longitude == city.longitude,
        );
      } else {
        savedCities.add(city);
      }
    });
    await _persistCities();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(exists ? 'City removed from saved list' : 'City saved')),
    );
  }

  Future<void> _removeSaved(City city) async {
    setState(() {
      savedCities.removeWhere(
        (c) => c.latitude == city.latitude && c.longitude == city.longitude,
      );
    });
    await _persistCities();
  }

  Future<void> _changeUnit(bool value) async {
    setState(() {
      fahrenheit = value;
      weather = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fahrenheit', value);
    if (selectedCity != null) {
      try {
        await _loadCity(selectedCity!);
      } catch (e) {
        if (mounted) {
          setState(() => error = 'Could not refresh weather for this unit.');
        }
      }
    }
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: CitySearchDelegate(onSearch: searchAndLoad),
    );
  }

  bool _isSaved() {
    if (selectedCity == null) return false;
    return savedCities.any(
      (c) =>
          c.latitude == selectedCity!.latitude &&
          c.longitude == selectedCity!.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weather Now',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search city',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    name: widget.userName,
                    email: widget.userEmail,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedTab,
        children: [
          _homePage(),
          _savedPage(),
          _settingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _homePage() {
    if (loading && weather == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (weather == null || selectedCity == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 60),
              const SizedBox(height: 12),
              Text(error ?? 'Weather is not available.'),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () => searchAndLoad('Guntur'),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final current = weather!['current'];
    final code = current['weather_code'] as int;
    final unit = fahrenheit ? '°F' : '°C';
    final currentTemp = current['temperature_2m'];

    return RefreshIndicator(
      onRefresh: () => _loadCity(selectedCity!),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 6),
          Text(
            'Hello, ${widget.userName}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedCity!.name}, ${selectedCity!.country}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleSaved,
                icon: Icon(
                  _isSaved() ? Icons.bookmark : Icons.bookmark_border,
                  color: accent,
                  size: 29,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF225B91), Color(0xFF19304F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                Icon(weatherIcon(code), size: 85, color: Colors.amberAccent),
                const SizedBox(height: 8),
                Text(
                  '$currentTemp$unit',
                  style: const TextStyle(
                    fontSize: 62,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  weatherDescription(code),
                  style: const TextStyle(fontSize: 19, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Feels like ${current['apparent_temperature']}$unit',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Weather details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _detailCard(
                'Humidity',
                '${current['relative_humidity_2m']}%',
                Icons.water_drop,
              ),
              const SizedBox(width: 12),
              _detailCard(
                'Wind',
                '${current['wind_speed_10m']} km/h',
                Icons.air,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _detailCard(
                'Feels like',
                '${current['apparent_temperature']}$unit',
                Icons.thermostat,
              ),
              const SizedBox(width: 12),
              _detailCard(
                'Condition',
                weatherDescription(code),
                Icons.cloud,
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hourly forecast',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _openHourlyDetails,
                child: const Text('See more'),
              ),
            ],
          ),
          _hourlyStrip(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '7-day forecast',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _openDailyDetails,
                child: const Text('See more'),
              ),
            ],
          ),
          _dailyForecast(),
          if (recentCities.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Recent searches',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: recentCities.take(5).map((city) {
                return ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 16),
                  label: Text(city.name),
                  onPressed: () async {
                    setState(() => loading = true);
                    try {
                      await _loadCity(city);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Weather data: Open-Meteo',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 25),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourlyStrip() {
    final hourly = weather!['hourly'];
    final times = hourly['time'] as List;
    final temps = hourly['temperature_2m'] as List;
    final codes = hourly['weather_code'] as List;
    final rain = hourly['precipitation_probability'] as List;
    final now = DateTime.now();

    int start = times.indexWhere(
      (t) => !DateTime.parse(t).isBefore(now),
    );
    if (start < 0) start = 0;

    final end = (start + 12).clamp(0, times.length);

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: end - start,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, itemIndex) {
          final i = start + itemIndex;
          return Container(
            width: 88,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(formatHour(times[i]), style: const TextStyle(fontSize: 12)),
                Icon(weatherIcon(codes[i]), color: Colors.amberAccent),
                Text('${temps[i]}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${rain[i]}% rain', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dailyForecast() {
    final daily = weather!['daily'];
    final dates = daily['time'] as List;
    final max = daily['temperature_2m_max'] as List;
    final min = daily['temperature_2m_min'] as List;
    final codes = daily['weather_code'] as List;

    return Column(
      children: List.generate(dates.length, (i) {
        final date = DateTime.parse(dates[i]);
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: Text(i == 0 ? 'Today' : '${date.day}/${date.month}')),
              Icon(weatherIcon(codes[i]), color: Colors.amberAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  weatherDescription(codes[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${max[i]}° / ${min[i]}°',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _openHourlyDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForecastScreen(
          title: 'Hourly forecast',
          city: selectedCity!,
          weather: weather!,
          hourly: true,
          fahrenheit: fahrenheit,
        ),
      ),
    );
  }

  void _openDailyDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForecastScreen(
          title: '7-day forecast',
          city: selectedCity!,
          weather: weather!,
          hourly: false,
          fahrenheit: fahrenheit,
        ),
      ),
    );
  }

  Widget _savedPage() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved cities',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          if (savedCities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No saved cities yet. Bookmark a city from Home.'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: savedCities.length,
              itemBuilder: (context, index) {
                final city = savedCities[index];
                return Card(
                  color: panel,
                  child: ListTile(
                    leading: const Icon(Icons.location_city, color: accent),
                    title: Text(city.name),
                    subtitle: Text(city.country),
                    onTap: () async {
                      setState(() {
                        selectedTab = 0;
                        loading = true;
                      });
                      try {
                        await _loadCity(city);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeSaved(city),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        Card(
          color: panel,
          child: SwitchListTile(
            secondary: const Icon(Icons.thermostat, color: accent),
            title: const Text('Temperature unit'),
            subtitle: Text(fahrenheit ? 'Fahrenheit (°F)' : 'Celsius (°C)'),
            value: fahrenheit,
            onChanged: _changeUnit,
          ),
        ),
        Card(
          color: panel,
          child: SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, color: accent),
            title: const Text('Light theme'),
            subtitle: const Text('Switch between light and dark appearance'),
            value: widget.lightTheme,
            onChanged: widget.onThemeChanged,
          ),
        ),
        Card(
          color: panel,
          child: const ListTile(
            leading: Icon(Icons.info_outline, color: accent),
            title: Text('About Weather Now'),
            subtitle: Text('Flutter weather app using Open-Meteo API.'),
          ),
        ),
      ],
    );
  }
}

// ---------------- CITY SEARCH ----------------

class CitySearchDelegate extends SearchDelegate<void> {
  final Future<void> Function(String) onSearch;

  CitySearchDelegate({required this.onSearch});

  @override
  String get searchFieldLabel => 'Enter city name';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          final value = query.trim();
          close(context, null);
          onSearch(value);
        },
        child: Text('Search "$query"'),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      child: Text(
        query.isEmpty ? 'Search for a city, e.g. Guntur' : 'Press search to find $query',
      ),
    );
  }
}

// ---------------- FORECAST DETAILS ----------------

class ForecastScreen extends StatelessWidget {
  final String title;
  final City city;
  final Map<String, dynamic> weather;
  final bool hourly;
  final bool fahrenheit;

  const ForecastScreen({
    super.key,
    required this.title,
    required this.city,
    required this.weather,
    required this.hourly,
    required this.fahrenheit,
  });

  @override
  Widget build(BuildContext context) {
    final unit = fahrenheit ? '°F' : '°C';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            city.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          if (hourly) ..._hourlyItems(unit) else ..._dailyItems(unit),
        ],
      ),
    );
  }

  List<Widget> _hourlyItems(String unit) {
    final data = weather['hourly'];
    final times = data['time'] as List;
    final temps = data['temperature_2m'] as List;
    final codes = data['weather_code'] as List;
    final rain = data['precipitation_probability'] as List;
    final now = DateTime.now();
    int start = times.indexWhere((t) => !DateTime.parse(t).isBefore(now));
    if (start < 0) start = 0;
    final end = (start + 24).clamp(0, times.length);

    return List.generate(end - start, (j) {
      final i = start + j;
      return Card(
        color: panel,
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: Icon(weatherIcon(codes[i]), color: Colors.amberAccent),
          title: Text(formatHour(times[i])),
          subtitle: Text('${weatherDescription(codes[i])} • ${rain[i]}% rain'),
          trailing: Text(
            '${temps[i]}$unit',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
      );
    });
  }

  List<Widget> _dailyItems(String unit) {
    final data = weather['daily'];
    final dates = data['time'] as List;
    final max = data['temperature_2m_max'] as List;
    final min = data['temperature_2m_min'] as List;
    final codes = data['weather_code'] as List;

    return List.generate(dates.length, (i) {
      final date = DateTime.parse(dates[i]);
      return Card(
        color: panel,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(weatherIcon(codes[i]), color: Colors.amberAccent, size: 30),
          title: Text(i == 0 ? 'Today' : '${date.day}/${date.month}/${date.year}'),
          subtitle: Text(weatherDescription(codes[i])),
          trailing: Text(
            '${max[i]}$unit / ${min[i]}$unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }
}

// ---------------- PROFILE ----------------

class ProfileScreen extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 52,
                backgroundColor: accent,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(
                name,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onLogout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
