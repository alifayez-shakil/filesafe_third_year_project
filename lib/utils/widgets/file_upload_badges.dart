import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/upload_manager.dart';

class UploadProgressBadge extends StatelessWidget {
  const UploadProgressBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadManager>(
      builder: (context, manager, child) {
        final tasks = manager.tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: () => _showExpanded(context, manager),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: tasks.length == 1
                  ? _buildSingleTask(tasks.first)
                  : _buildSummary(tasks),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleTask(UploadTask task) {
    final isComplete = task.status == UploadStatus.completed;
    final isFailed = task.status == UploadStatus.failed;

    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isComplete
              ? const Icon(
                  Icons.shield,
                  color: Colors.green,
                  size: 24,
                  key: ValueKey('done'),
                )
              : isFailed
              ? const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 24,
                  key: ValueKey('error'),
                )
              : SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: task.totalBytes > 0
                        ? task.uploadedBytes / task.totalBytes
                        : null,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.amber),
                    key: ValueKey('progress'),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isFailed ? (task.errorMessage.isNotEmpty ? task.errorMessage : 'Upload failed') : _statusDescription(task),
                style: TextStyle(
                  fontSize: 11,
                  color: isFailed ? Colors.red[700] : Colors.grey[600],
                  fontWeight: isFailed ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (!isComplete && !isFailed)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.totalBytes > 0
                        ? task.uploadedBytes / task.totalBytes
                        : null,
                    backgroundColor: Colors.grey[200],
                    minHeight: 4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<UploadTask> tasks) {
    final active = tasks
        .where((t) => t.status != UploadStatus.completed)
        .length;
    return Row(
      children: [
        const Icon(Icons.cloud_upload, color: Colors.amber, size: 24),
        const SizedBox(width: 12),
        Text('$active file(s) uploading…'),
        const Spacer(),
        Text(
          '${tasks.where((t) => t.status == UploadStatus.completed).length} done',
        ),
      ],
    );
  }

  String _statusDescription(UploadTask task) {
    switch (task.status) {
      case UploadStatus.encrypting:
        return 'Encrypting locally…';
      case UploadStatus.streaming:
        return 'Streaming blocks…';
      case UploadStatus.syncing:
        return 'Synchronizing database indexes…';
      case UploadStatus.completed:
        return 'Upload complete!';
      case UploadStatus.failed:
        return 'Upload failed';
    }
  }

  void _showExpanded(BuildContext context, UploadManager manager) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: manager.tasks
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSingleTask(t),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
