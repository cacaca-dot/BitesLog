import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../../services/api_service.dart';
import '../globals.dart';
import '../../features/profile/profile_page.dart';

class ThreadedCommentsSection extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String? currentUserId;
  final String? contentOwnerId; // Owner of the visit or list (for moderation)
  final String? focusCommentId;
  final Function(int) onCountChanged;
  final VoidCallback? onCommentsChanged;

  const ThreadedCommentsSection({
    super.key,
    required this.targetType,
    required this.targetId,
    this.currentUserId,
    this.contentOwnerId,
    this.focusCommentId,
    required this.onCountChanged,
    this.onCommentsChanged,
  });

  @override
  State<ThreadedCommentsSection> createState() => _ThreadedCommentsSectionState();
}

class _ThreadedCommentsSectionState extends State<ThreadedCommentsSection> with RouteAware, WidgetsBindingObserver {
  List<dynamic> _comments = [];
  bool _isLoading = true;
  
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSubmittingComment = false;
  
  String? _replyingToCommentId;
  String? _replyingToUsername;
  
  Set<String> _expandedThreads = {};
  
  int _refetchCounter = 0;
  DateTime? _lastFetchTime;
  bool _isSubscribed = false;

  final Map<String, GlobalKey> _commentKeys = {};
  String? _highlightedCommentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchComments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _isSubscribed = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshComments();
    }
  }

  @override
  void didPopNext() {
    _refreshComments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  // B9: Only count top-level comments, not replies
  int get _topLevelCount => _comments.where((c) => c['parent_comment_id'] == null).length;

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await ApiService.getComments(widget.targetType, widget.targetId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
        widget.onCountChanged(_topLevelCount);
        
        if (widget.focusCommentId != null) {
          _handleFocusComment(widget.focusCommentId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFocusComment(String commentId) {
    bool found = false;
    for (var c in _comments) {
      if (c['id'].toString() == commentId) {
        found = true;
        break;
      }
      if (c['replies'] != null) {
        for (var r in c['replies']) {
          if (r['id'].toString() == commentId) {
            found = true;
            _expandedThreads.add(c['id'].toString());
            break;
          }
        }
      }
      if (found) break;
    }

    if (found) {
      setState(() {
        _highlightedCommentId = commentId;
      });
      
      Future.delayed(const Duration(milliseconds: 300), () {
        final key = _commentKeys[commentId];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _highlightedCommentId = null;
            });
          }
        });
      });
    }
  }

  Future<void> _refreshComments() async {
    if (_lastFetchTime != null && DateTime.now().difference(_lastFetchTime!).inSeconds < 1) {
      return;
    }
    _lastFetchTime = DateTime.now();

    _refetchCounter++;
    final currentCounter = _refetchCounter;

    try {
      final comments = await ApiService.getComments(widget.targetType, widget.targetId);
      if (mounted && currentCounter == _refetchCounter) {
        setState(() {
          _comments = comments;
        });
        widget.onCountChanged(_topLevelCount);
      }
    } catch (e) {
      // Ignore silent refresh error
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    // Remove mention prefix if replying
    String cleanText = text;
    if (_replyingToUsername != null) {
      final prefix = '@$_replyingToUsername ';
      if (cleanText.startsWith(prefix)) {
        cleanText = cleanText.substring(prefix.length).trim();
      }
    }
    
    if (cleanText.isEmpty) return;

    setState(() => _isSubmittingComment = true);
    try {
      await ApiService.addComment(
        widget.targetType, 
        widget.targetId, 
        cleanText, 
        parentCommentId: _replyingToCommentId
      );
      
      _commentController.clear();
      _replyingToCommentId = null;
      _replyingToUsername = null;
      _commentFocusNode.unfocus();
      
      if (widget.onCommentsChanged != null) {
        widget.onCommentsChanged!();
      }
      
      final comments = await ApiService.getComments(widget.targetType, widget.targetId);
      if (mounted) {
        setState(() => _comments = comments);
        widget.onCountChanged(_topLevelCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Komentar?'),
        content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteComment(commentId);
      if (widget.onCommentsChanged != null) {
        widget.onCommentsChanged!();
      }
      final comments = await ApiService.getComments(widget.targetType, widget.targetId);
      if (mounted) {
        setState(() => _comments = comments);
        widget.onCountChanged(_topLevelCount);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  void _navigateToProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: userId,
          isCurrentUser: widget.currentUserId != null && userId == widget.currentUserId,
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> c, bool isReply, bool isMyComment) {
    final commentId = c['id'].toString();
    _commentKeys[commentId] ??= GlobalKey();
    
    final bool isHighlighted = _highlightedCommentId == commentId;

    return Container(
      key: _commentKeys[commentId],
      color: isHighlighted ? AppColors.accent.withOpacity(0.5) : Colors.transparent,
      padding: EdgeInsets.only(bottom: 12, left: isReply ? 40 : 0, top: isHighlighted ? 8 : 0, right: isHighlighted ? 8 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _navigateToProfile(c['user_id']?.toString()),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: isReply ? 12 : 16,
              backgroundColor: AppColors.accent,
              child: Text(c['username'] != null && c['username'].toString().isNotEmpty ? c['username'][0].toUpperCase() : 'U', style: TextStyle(fontSize: isReply ? 10 : 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => _navigateToProfile(c['user_id']?.toString()),
                      child: Text(c['username'] ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isReply ? 12 : 13)),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatDate(c['created_at'] ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c['comment_text'] ?? '', style: TextStyle(fontSize: isReply ? 13 : 14)),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_replyingToUsername != null) {
                        final oldPrefix = '@$_replyingToUsername ';
                        if (_commentController.text.startsWith(oldPrefix)) {
                          _commentController.text = _commentController.text.substring(oldPrefix.length);
                        }
                      }
                      
                      _replyingToCommentId = c['id'].toString();
                      _replyingToUsername = c['username']?.toString() ?? 'User';
                      
                      final newPrefix = '@$_replyingToUsername ';
                      _commentController.text = newPrefix + _commentController.text;
                      _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                    });
                    _commentFocusNode.requestFocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4, right: 16),
                    child: Text('Balas', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          if (isMyComment || widget.contentOwnerId == widget.currentUserId)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _deleteComment(c['id'].toString()),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // COMMENTS LIST
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Komentar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              
              if (_comments.isEmpty)
                const Text('Belum ada komentar', style: TextStyle(color: Colors.grey))
              else
                Builder(
                  builder: (context) {
                    final parents = _comments.where((c) => c['parent_comment_id'] == null).toList();
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: parents.length,
                      itemBuilder: (ctx, i) {
                        final parent = parents[i];
                        final parentId = parent['id']?.toString();
                        final replies = _comments.where((c) => c['parent_comment_id']?.toString() == parentId).toList();
                        
                        final isMyParent = widget.currentUserId != null && parent['user_id']?.toString() == widget.currentUserId;
                        
                        final parentIdStr = parentId ?? '';
                        final isExpanded = _expandedThreads.contains(parentIdStr);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCommentItem(parent, false, isMyParent),
                            if (replies.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 40, bottom: 12),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedThreads.remove(parentIdStr);
                                      } else {
                                        _expandedThreads.add(parentIdStr);
                                      }
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 24, height: 1, color: Colors.grey.withOpacity(0.5)),
                                      const SizedBox(width: 8),
                                      Text(
                                        isExpanded ? 'Sembunyikan balasan' : 'Lihat ${replies.length} balasan',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (isExpanded)
                              for (final reply in replies)
                                _buildCommentItem(
                                  reply, 
                                  true, 
                                  widget.currentUserId != null && reply['user_id']?.toString() == widget.currentUserId
                                ),
                          ],
                        );
                      },
                    );
                  }
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        
        // COMMENT INPUT
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToUsername != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 8),
                    child: Row(
                      children: [
                        Text('Membalas @$_replyingToUsername', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() {
                            if (_replyingToUsername != null) {
                              final oldPrefix = '@$_replyingToUsername ';
                              if (_commentController.text.startsWith(oldPrefix)) {
                                _commentController.text = _commentController.text.substring(oldPrefix.length);
                              }
                            }
                            _replyingToCommentId = null;
                            _replyingToUsername = null;
                          }),
                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Tulis komentar...',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSubmittingComment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: _addComment,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
