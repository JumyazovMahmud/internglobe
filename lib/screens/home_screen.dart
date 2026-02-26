import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/internship.dart';
import '../services/api_service.dart';
import '../widgets/internship_card.dart';
import 'profile_screen.dart';
import 'apply_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();

  // ── Discover state ──────────────────────────────────────────
  List<Internship> _internships = [];
  List<Internship> _filteredInternships = [];
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;

  // ── For You state ───────────────────────────────────────────
  List<Internship> _forYouInternships = [];
  bool _forYouLoading = false;
  bool _forYouInitialLoad = true;
  String? _forYouError;
  List<String> _userInterests = [];
  int _forYouInterestIndex = 0;
  int _forYouPage = 1;
  bool _forYouHasMore = true;

  // ── Shared UI state ─────────────────────────────────────────
  final _searchController = TextEditingController();
  final _regionController = TextEditingController();
  Timer? _debounce;
  Timer? _regionDebounce;
  bool _remoteOnly = false;
  String _selectedCategory = 'All';
  int _bottomNavIndex = 0;
  int _tabIndex = 0;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _forYouScrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const int _pageSize = 10;
  final List<String> _categories = ['All', 'Tech', 'Marketing', 'Design', 'Business', 'Data'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scrollController.addListener(_onScroll);
    _forYouScrollController.addListener(_onForYouScroll);
    _searchController.addListener(_onSearchChanged);
    _loadCachedData();
    _loadInternships();
    _loadUserInterests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _regionController.dispose();
    _debounce?.cancel();
    _regionDebounce?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    _forYouScrollController.dispose();
    super.dispose();
  }

  // ── Cache ────────────────────────────────────────────────────

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_internships');
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        setState(() {
          _internships = jsonList.map((j) => Internship.fromJson(j)).toList();
          _filteredInternships = _internships;
          _isInitialLoad = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _internships.map((i) => i.toJson()).toList();
      await prefs.setString('cached_internships', json.encode(jsonList));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  // ── User interests ───────────────────────────────────────────

  Future<void> _loadUserInterests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseDatabase.instance.ref('users/$uid/favorites');
      final event = await ref.once();
      final data = event.snapshot.value;
      if (data != null) {
        final list = (data as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        setState(() => _userInterests = list);
        _loadForYou();
      } else {
        setState(() {
          _forYouInitialLoad = false;
          _forYouLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _forYouError = 'Could not load your interests.';
        _forYouInitialLoad = false;
      });
    }
  }

  /// Called by ProfileScreen when the user saves new interests.
  void _onInterestsUpdated(List<String> newInterests) {
    setState(() {
      _userInterests = newInterests;
      // Reset For You so it reloads with the new interests
      _forYouInternships.clear();
      _forYouPage = 1;
      _forYouHasMore = true;
      _forYouInterestIndex = 0;
      _forYouInitialLoad = true;
      _forYouError = null;
    });
    // If the user is currently on the For You tab, reload immediately
    if (_tabIndex == 1) {
      _loadForYou();
    }
  }

  // ── Discover loading ─────────────────────────────────────────

  String? _buildTitleFilter() {
    String filter = _searchController.text.trim();
    if (_selectedCategory != 'All') {
      if (filter.isNotEmpty) filter += ' ';
      filter += _selectedCategory.toLowerCase();
    }
    return filter.isEmpty ? null : filter;
  }

  Future<void> _loadInternships({bool isLoadMore = false}) async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      if (!isLoadMore) {
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
        _internships.clear();
        _filteredInternships.clear();
      }
    });
    try {
      final newInternships = await _apiService.fetchInternships(
        titleFilter: _buildTitleFilter(),
        locationFilter: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
        remote: _remoteOnly,
        offset: (_currentPage - 1) * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _internships.addAll(newInternships);
        _filteredInternships.addAll(newInternships);
        _hasMore = newInternships.length == _pageSize;
        _isLoading = false;
        _isInitialLoad = false;
        if (isLoadMore) _currentPage++;
      });
      _cacheData();
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        if (isLoadMore) _hasMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300 && !_isLoading && _hasMore) {
      _loadInternships(isLoadMore: true);
    }
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _internships.clear();
      _filteredInternships.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadInternships();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _resetAndLoad());
  }

  // ── For You loading ──────────────────────────────────────────

  Future<void> _loadForYou({bool isLoadMore = false}) async {
    if (_forYouLoading || _userInterests.isEmpty) return;
    if (isLoadMore && !_forYouHasMore) return;

    setState(() {
      _forYouLoading = true;
      if (!isLoadMore) {
        _forYouError = null;
        _forYouInternships.clear();
        _forYouInterestIndex = 0;
        _forYouPage = 1;
        _forYouHasMore = true;
      }
    });

    try {
      if (!isLoadMore) {
        // Fetch ALL interests in parallel
        final futures = _userInterests.map((interest) =>
            _apiService.fetchInternships(
              titleFilter: interest,
              remote: false,
              offset: 0,
            ));
        final results = await Future.wait(futures);
        if (!mounted) return;

        // Merge and deduplicate by URL
        final seen = <String>{};
        final deduped = results
            .expand((list) => list)
            .where((i) => seen.add(i.url))
            .toList();

        setState(() {
          _forYouInternships = deduped;
          _forYouLoading = false;
          _forYouInitialLoad = false;
          _forYouHasMore = results.any((r) => r.length == _pageSize);
          _forYouInterestIndex = 0;
          _forYouPage = 2;
        });
      } else {
        // Load more: cycle through interests round-robin
        final interest = _userInterests[_forYouInterestIndex % _userInterests.length];
        final newInternships = await _apiService.fetchInternships(
          titleFilter: interest,
          remote: false,
          offset: (_forYouPage - 1) * _pageSize,
        );
        if (!mounted) return;

        final existingUrls = _forYouInternships.map((i) => i.url).toSet();
        final fresh = newInternships.where((i) => !existingUrls.contains(i.url)).toList();

        setState(() {
          _forYouInternships.addAll(fresh);
          _forYouLoading = false;
          _forYouInitialLoad = false;
          _forYouInterestIndex++;
          if (_forYouInterestIndex % _userInterests.length == 0) _forYouPage++;
          _forYouHasMore = newInternships.length == _pageSize;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _forYouLoading = false;
        _forYouInitialLoad = false;
        _forYouError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onForYouScroll() {
    if (_forYouScrollController.position.extentAfter < 300 && !_forYouLoading && _forYouHasMore) {
      _loadForYou(isLoadMore: true);
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildMainContent(),
      ProfileScreen(onInterestsUpdated: _onInterestsUpdated),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[50],
      body: screens[_bottomNavIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: (i) => setState(() => _bottomNavIndex = i),
          selectedItemColor: Colors.blue[700],
          unselectedItemColor: Colors.grey[400],
          elevation: 0,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'InternGlobe',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find your dream internship',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 16),
                if (_tabIndex == 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search internships...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            _searchController.clear();
                            _resetAndLoad();
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildTab('Discover', 0),
                    const SizedBox(width: 8),
                    _buildTab('For You', 1),
                  ],
                ),
              ],
            ),
          ),

          // ── Filters (Discover only) ──────────────────────────
          if (_tabIndex == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? cat : 'All';
                                _resetAndLoad();
                              });
                            },
                            backgroundColor: Colors.grey[200],
                            selectedColor: Colors.blue[700],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[800],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            checkmarkColor: Colors.white,
                            elevation: isSelected ? 2 : 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: _regionController.text.isNotEmpty ? Colors.blue[50] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _regionController.text.isNotEmpty ? Colors.blue[700]! : Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _regionController,
                              onChanged: (_) {
                                _regionDebounce?.cancel();
                                _regionDebounce = Timer(const Duration(milliseconds: 400), () {
                                  setState(() {});
                                  _resetAndLoad();
                                });
                              },
                              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              decoration: InputDecoration(
                                hintText: 'Region or country...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.public, size: 18, color: Colors.blue[400]),
                                suffixIcon: _regionController.text.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
                                  onPressed: () {
                                    _regionController.clear();
                                    setState(() {});
                                    _resetAndLoad();
                                  },
                                )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _remoteOnly = !_remoteOnly);
                            _resetAndLoad();
                          },
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _remoteOnly ? Colors.blue[50] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _remoteOnly ? Colors.blue[700]! : Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wifi, size: 16, color: _remoteOnly ? Colors.blue[700] : Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text(
                                  'Remote',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _remoteOnly ? Colors.blue[700] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${_filteredInternships.length} opportunities',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  if (_isLoading && !_isInitialLoad)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── For You header ───────────────────────────────────
          if (_tabIndex == 1 && _userInterests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Based on: ${_userInterests.join(', ')}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _tabIndex == 0 ? _buildDiscoverList() : _buildForYouList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = index);
        if (index == 1 && _forYouInternships.isEmpty && !_forYouLoading && _userInterests.isNotEmpty) {
          _loadForYou();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue[700] : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverList() {
    if (_errorMessage != null && _internships.isEmpty) return _buildError(_errorMessage!, _resetAndLoad);
    if (_isInitialLoad && _isLoading) return _buildLoading();
    if (_filteredInternships.isEmpty && !_isLoading) return _buildEmpty();
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _resetAndLoad,
        color: Colors.blue[700],
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: _filteredInternships.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, i) {
            if (i < _filteredInternships.length) return _animatedCard(_filteredInternships[i], i);
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          },
        ),
      ),
    );
  }

  Widget _buildForYouList() {
    if (_userInterests.isEmpty && !_forYouLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              Text('No interests set',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Text(
                'Add your career interests in Profile to see personalised internships here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _bottomNavIndex = 1),
                icon: const Icon(Icons.edit),
                label: const Text('Go to Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_forYouError != null && _forYouInternships.isEmpty) return _buildError(_forYouError!, _loadForYou);
    if (_forYouInitialLoad && _forYouLoading) return _buildLoading();
    if (_forYouInternships.isEmpty && !_forYouLoading) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _forYouInternships.clear();
          _forYouPage = 1;
          _forYouHasMore = true;
          _forYouInterestIndex = 0;
        });
        await _loadForYou();
      },
      color: Colors.blue[700],
      child: ListView.builder(
        controller: _forYouScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _forYouInternships.length + (_forYouLoading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < _forYouInternships.length) return _animatedCard(_forYouInternships[i], i);
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }

  Widget _animatedCard(Internship internship, int i) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (i * 40).clamp(0, 600)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: InternshipCard(
        internship: internship,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ApplyScreen(internship: internship)),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!)),
          const SizedBox(height: 16),
          Text('Loading opportunities...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text('Oops! Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text('No results found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text('Try adjusting your filters or search terms',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}