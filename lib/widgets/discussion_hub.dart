import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/discussion_service.dart';
import '../theme/app_colors.dart';

/// The real per-lesson Discussion Hub - students can ask questions, reply
/// and like each other's comments under the class they're watching, backed
/// by GET/POST /api/discussions and PUT /api/discussions/:id/like
/// (server/controllers/DiscussionController.js), matching
/// client/src/pages/student/CoursePlayer.jsx's discussionHubBlock.
class DiscussionHub extends StatefulWidget {
  const DiscussionHub({super.key, required this.courseId, required this.videoId, required this.token});

  final String courseId;
  final String videoId;
  final String token;

  @override
  State<DiscussionHub> createState() => _DiscussionHubState();
}

class _DiscussionHubState extends State<DiscussionHub> {
  List<Discussion>? _discussions;
  AuthUser? _currentUser;
  final _commentController = TextEditingController();
  bool _posting = false;
  String? _replyingToId;
  final _replyController = TextEditingController();
  bool _postingReply = false;
  final Set<String> _likeInFlight = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DiscussionService.instance.fetchDiscussions(widget.courseId, widget.videoId, widget.token),
      AuthService.instance.restoreSession(),
    ]);
    if (!mounted) return;
    setState(() {
      _discussions = results[0] as List<Discussion>;
      _currentUser = results[1] as AuthUser?;
    });
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _posting) return;
    setState(() => _posting = true);
    final discussion = await DiscussionService.instance.postDiscussion(
      courseId: widget.courseId,
      videoId: widget.videoId,
      content: content,
      token: widget.token,
    );
    if (!mounted) return;
    setState(() {
      _posting = false;
      if (discussion != null) {
        _discussions = [discussion, ...?_discussions];
        _commentController.clear();
      }
    });
  }

  Future<void> _postReply(String parentId) async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _postingReply) return;
    setState(() => _postingReply = true);
    final reply = await DiscussionService.instance.postDiscussion(
      courseId: widget.courseId,
      videoId: widget.videoId,
      content: content,
      parentId: parentId,
      token: widget.token,
    );
    if (!mounted) return;
    setState(() {
      _postingReply = false;
      if (reply != null) {
        _discussions = [reply, ...?_discussions];
        _replyController.clear();
        _replyingToId = null;
      }
    });
  }

  Future<void> _toggleLike(Discussion discussion) async {
    if (_likeInFlight.contains(discussion.id)) return;
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) return;

    setState(() {
      _likeInFlight.add(discussion.id);
      _discussions = _discussions
          ?.map((d) {
            if (d.id != discussion.id) return d;
            final likedBy = [...d.likedBy];
            if (likedBy.contains(currentUserId)) {
              likedBy.remove(currentUserId);
            } else {
              likedBy.add(currentUserId);
            }
            return Discussion(
              id: d.id,
              userId: d.userId,
              userName: d.userName,
              userProfileImage: d.userProfileImage,
              content: d.content,
              parentId: d.parentId,
              createdAt: d.createdAt,
              likedBy: likedBy,
            );
          })
          .toList();
    });

    final likedBy = await DiscussionService.instance.toggleLike(discussion.id, widget.token);
    if (!mounted) return;
    setState(() {
      _likeInFlight.remove(discussion.id);
      if (likedBy != null) {
        _discussions = _discussions?.map((d) {
          if (d.id != discussion.id) return d;
          return Discussion(
            id: d.id,
            userId: d.userId,
            userName: d.userName,
            userProfileImage: d.userProfileImage,
            content: d.content,
            parentId: d.parentId,
            createdAt: d.createdAt,
            likedBy: likedBy,
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final discussions = _discussions;
    final topLevel = (discussions ?? const []).where((d) => !d.isReply).toList();
    List<Discussion> repliesOf(String id) =>
        (discussions ?? const []).where((d) => d.parentId == id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.forum_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Discussion Hub',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: _currentUser?.name ?? '', imageUrl: ''),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      minLines: 2,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Write your thought or question here...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.fieldBackground,
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: _posting ? null : _postComment,
                        icon: _posting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 15),
                        label: const Text('Post', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (discussions == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (topLevel.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No discussions yet. Be the first to ask a question!',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          for (final msg in topLevel) ...[
            _CommentRow(
              message: msg,
              isReply: false,
              currentUserId: _currentUser?.id,
              isLikeInFlight: _likeInFlight.contains(msg.id),
              onToggleLike: () => _toggleLike(msg),
              onReply: () => setState(() {
                _replyingToId = _replyingToId == msg.id ? null : msg.id;
                _replyController.clear();
              }),
              isReplying: _replyingToId == msg.id,
              replyController: _replyController,
              onSubmitReply: () => _postReply(msg.id),
              submittingReply: _postingReply,
            ),
            for (final reply in repliesOf(msg.id))
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 8),
                child: _CommentRow(
                  message: reply,
                  isReply: true,
                  currentUserId: _currentUser?.id,
                  isLikeInFlight: _likeInFlight.contains(reply.id),
                  onToggleLike: () => _toggleLike(reply),
                  onReply: null,
                  isReplying: false,
                  replyController: _replyController,
                  onSubmitReply: () {},
                  submittingReply: false,
                ),
              ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.message,
    required this.isReply,
    required this.currentUserId,
    required this.isLikeInFlight,
    required this.onToggleLike,
    required this.onReply,
    required this.isReplying,
    required this.replyController,
    required this.onSubmitReply,
    required this.submittingReply,
  });

  final Discussion message;
  final bool isReply;
  final String? currentUserId;
  final bool isLikeInFlight;
  final VoidCallback onToggleLike;
  final VoidCallback? onReply;
  final bool isReplying;
  final TextEditingController replyController;
  final VoidCallback onSubmitReply;
  final bool submittingReply;

  @override
  Widget build(BuildContext context) {
    final isLiked = currentUserId != null && message.likedBy.contains(currentUserId);

    return Container(
      padding: isReply ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: isReply
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: message.userName, imageUrl: message.userProfileImage, small: isReply),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.userName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      '${message.createdAt.day}/${message.createdAt.month}/${message.createdAt.year}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: isLikeInFlight ? null : onToggleLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 13,
                            color: isLiked ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.likedBy.isNotEmpty ? '${message.likedBy.length}' : 'Like',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isLiked ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onReply != null) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: onReply,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply_rounded, size: 13, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (isReplying) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.fieldBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: submittingReply ? null : onSubmitReply,
                        icon: submittingReply
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.imageUrl, this.small = false});

  final String name;
  final String imageUrl;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 24.0 : 32.0;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (context, error, stackTrace) => Text(
                initial,
                style: TextStyle(fontSize: small ? 10 : 12.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            )
          : Text(
              initial,
              style: TextStyle(fontSize: small ? 10 : 12.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
    );
  }
}
