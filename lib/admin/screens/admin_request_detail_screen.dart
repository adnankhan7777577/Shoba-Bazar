import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_snackbar.dart';

class AdminRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onStatusChanged;

  const AdminRequestDetailScreen({
    super.key,
    required this.request,
    this.onStatusChanged,
  });

  @override
  State<AdminRequestDetailScreen> createState() => _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends State<AdminRequestDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isUpdating = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            _buildHeader(),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seller Details Section
                    _buildSellerDetailsSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Row with Back Button and Title
            Row(
              children: [
                // Back Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Title
                Expanded(
                  child: Text(
                    'Request',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Seller Avatar and Name
            Column(
              children: [
                // Seller Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: widget.request['profile_picture_url'] != null && 
                         (widget.request['profile_picture_url'] as String).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(38),
                          child: Image.network(
                            widget.request['profile_picture_url'] as String,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.build,
                                color: Colors.grey,
                                size: 40,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.build,
                          color: Colors.grey,
                          size: 40,
                        ),
                ),
                
                const SizedBox(height: 12),
                
                // Seller Name
                Text(
                  widget.request['sellerName'],
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email
          _buildDetailRow(
            icon: Icons.email,
            label: 'Email',
            value: widget.request['email'],
          ),
          
          const SizedBox(height: 16),
          
          // Phone
          _buildDetailRow(
            icon: Icons.phone,
            label: 'Phone',
            value: widget.request['phone'],
          ),
          
          const SizedBox(height: 16),
          
          // Address
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'Address',
            value: widget.request['address'],
          ),
          
          const SizedBox(height: 16),

          // Shop Address
          _buildDetailRow(
            icon: Icons.store_mall_directory,
            label: 'Shop Address',
            value: (widget.request['shopAddress'] ?? widget.request['shop_address'] ?? widget.request['shopLocation'] ?? '').toString().isNotEmpty
                ? (widget.request['shopAddress'] ?? widget.request['shop_address'] ?? widget.request['shopLocation']).toString()
                : '-',
          ),
          
          const SizedBox(height: 16),
          
          // Country
          _buildDetailRow(
            icon: Icons.public,
            label: 'Country',
            value: widget.request['country'],
          ),
          
          const SizedBox(height: 16),
          
          // City
          _buildDetailRow(
            icon: Icons.location_city,
            label: 'City',
            value: widget.request['city'],
          ),
          
          const SizedBox(height: 16),
          
          // WhatsApp
          _buildDetailRow(
            icon: Icons.chat,
            label: 'WhatsApp',
            value: widget.request['whatsapp'],
          ),
          
          const SizedBox(height: 16),
          
          
          const SizedBox(height: 16),
          
          // Request Date
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: 'Request Date',
            value: widget.request['requestDate'],
          ),
          
          const SizedBox(height: 16),
          
          // Status
          _buildDetailRow(
            icon: Icons.info,
            label: 'Status',
            value: widget.request['status'].toUpperCase(),
            isStatus: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isStatus = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textLight,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (isStatus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(value).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(value),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    value,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _getStatusColor(value),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButtons() {
    if (_isUpdating) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
          ),
        ),
      );
    }

    final status = widget.request['status'] as String? ?? 'pending';

    // If approved, show message
    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'This request has been approved',
            style: AppTextStyles.bodyLarge.copyWith(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // If rejected, show only Approve button
    if (status == 'rejected') {
      return Row(
        children: [
          // Approve Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showAcceptConfirmation();
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.adminPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.adminPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Approve',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // If pending, show both Approve and Reject buttons
    return Row(
      children: [
        // Accept Button
        Expanded(
          child: GestureDetector(
            onTap: () {
              _showAcceptConfirmation();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.adminPrimary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.adminPrimary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Accept',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Reject Button
        Expanded(
          child: GestureDetector(
            onTap: () {
              _showRejectConfirmation();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'Reject',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAcceptConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.adminPrimary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Accept Request',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to accept this seller request?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _acceptRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Accept',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRejectConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cancel,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Reject Request',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to reject this seller request?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Reject',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptRequest() async {
    final sellerId = widget.request['seller_id'] as String?;
    if (sellerId == null) {
      CustomSnackBar.showError(context, 'Seller ID not found');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Update seller approval status to 'approved'
      await _supabase
          .from('sellers')
          .update({'approval_status': 'approved'})
          .eq('id', sellerId);

      setState(() {
        widget.request['status'] = 'approved';
        _isUpdating = false;
      });

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Seller request approved successfully!');
        // Notify parent to refresh list
        widget.onStatusChanged?.call();
        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      print('Error approving request: $e');
      setState(() {
        _isUpdating = false;
      });
      if (mounted) {
        CustomSnackBar.showError(context, 'Failed to approve request: ${e.toString()}');
      }
    }
  }

  Future<void> _rejectRequest() async {
    final sellerId = widget.request['seller_id'] as String?;
    if (sellerId == null) {
      CustomSnackBar.showError(context, 'Seller ID not found');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Update seller approval status to 'rejected'
      await _supabase
          .from('sellers')
          .update({'approval_status': 'rejected'})
          .eq('id', sellerId);

      setState(() {
        widget.request['status'] = 'rejected';
        _isUpdating = false;
      });

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Seller request rejected');
        // Notify parent to refresh list
        widget.onStatusChanged?.call();
        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      print('Error rejecting request: $e');
      setState(() {
        _isUpdating = false;
      });
      if (mounted) {
        CustomSnackBar.showError(context, 'Failed to reject request: ${e.toString()}');
      }
    }
  }

}
