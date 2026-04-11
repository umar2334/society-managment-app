// lib/screens/maintenance_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import 'app_theme.dart';
import 'society_data.dart';

class MaintenanceScreen extends StatefulWidget {
  final bool isAdmin;
  const MaintenanceScreen({super.key, this.isAdmin = false});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _picker = ImagePicker();

  // Cloudinary pe upload karo — free, permanent URL, sab phones par dikhe
  Future<String> _uploadImage(String localPath, String memberId) async {
    return CloudinaryService.uploadImage(
      File(localPath),
      folder: 'maintenance_team',
    );
  }

  void _showEditDialog({int? index}) {
    final isNew     = index == null;
    final existing  = isNew ? null : SocietyData.maintenanceTeam[index];

    final nameCtrl  = TextEditingController(text: existing?['name']     ?? '');
    final posCtrl   = TextEditingController(text: existing?['position'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']    ?? '');

    // ✅ imageUrl = Firebase URL (permanent), imgPath = naya local path
    String imgPath  = '';
    String imageUrl = existing?['imageUrl'] ?? existing?['imagePath'] ?? '';
    String err      = '';
    bool   uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 44, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              // Header
              Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: AppTheme.brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.engineering_rounded,
                      color: AppTheme.brand, size: 24)),
                const SizedBox(width: 14),
                Text(isNew ? 'new Member Add' : 'Member Edit Karo',
                    style: GoogleFonts.sora(fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ]),
              const SizedBox(height: 24),

              // ✅ Photo section — Firebase URL ya naya local path dono handle karo
              GestureDetector(
                onTap: uploading ? null : () async {
                  final picked = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 75);
                  if (picked != null) setS(() => imgPath = picked.path);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.brand.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    // Preview — naya local path ho toh File.image, warna Firebase URL
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppTheme.brand.withOpacity(0.1)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imgPath.isNotEmpty && File(imgPath).existsSync()
                            ? Image.file(File(imgPath), fit: BoxFit.cover)
                            : imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person_rounded,
                                            color: AppTheme.brand, size: 32),
                                  )
                                : const Icon(Icons.person_rounded,
                                    color: AppTheme.brand, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Photo Select Karo',
                          style: GoogleFonts.sora(fontWeight: FontWeight.w700,
                              color: AppTheme.brand, fontSize: 13)),
                      Text('Gallery se photo choose karein',
                          style: GoogleFonts.sora(fontSize: 11,
                              color: AppTheme.textMuted)),
                      if (imgPath.isNotEmpty || imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            imgPath.isNotEmpty
                                ? 'Naya photo selected!'
                                : 'Photo already set ✓',
                            style: GoogleFonts.sora(fontSize: 10,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ])),
                    const Icon(Icons.photo_library_rounded,
                        color: AppTheme.brand, size: 22),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_rounded, color: AppTheme.brand),
                ),
              ),
              const SizedBox(height: 12),

              // Position
              TextField(
                controller: posCtrl,
                style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Position / Post',
                  hintText: 'e.g. Electrician, Plumber, Guard...',
                  prefixIcon: Icon(Icons.work_rounded, color: AppTheme.brand),
                ),
              ),
              const SizedBox(height: 12),

              // Phone
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_rounded, color: AppTheme.brand),
                ),
              ),

              if (err.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.danger.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.danger, size: 16),
                    const SizedBox(width: 8),
                    Text(err, style: GoogleFonts.sora(
                        color: AppTheme.danger, fontSize: 11)),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  icon: uploading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    uploading
                        ? 'Photo Upload Ho Rahi Hai...'
                        : isNew ? 'ADD MEMBER' : 'SAVE CHANGES',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: uploading ? null : () async {
                    final name = nameCtrl.text.trim();
                    final pos  = posCtrl.text.trim();
                    if (name.isEmpty) {
                      setS(() => err = 'Naam zaroor likhein!');
                      return;
                    }
                    if (pos.isEmpty) {
                      setS(() => err = 'Position zaroor likhein!');
                      return;
                    }

                    // ✅ ID pehle properly set karo
                    final memberId = (existing?['id'] as String? ?? '').isNotEmpty
                        ? existing!['id'] as String
                        : DateTime.now().millisecondsSinceEpoch.toString();

                    // ✅ Naya photo select kiya hai toh Firebase Storage mein upload karo
                    if (imgPath.isNotEmpty) {
                      setS(() => uploading = true);
                      final uploadedUrl = await _uploadImage(imgPath, memberId);
                      if (uploadedUrl.isNotEmpty) {
                        imageUrl = uploadedUrl;
                      } else {
                        setS(() { uploading = false; err = 'Photo upload fail! Net check karein.'; });
                        return;
                      }
                      setS(() => uploading = false);
                    }

                    final member = {
                      'id':       memberId,
                      'name':     name,
                      'position': pos,
                      'phone':    phoneCtrl.text.trim(),
                      'imageUrl': imageUrl, // ✅ Sirf Firebase URL save karo
                    };

                    await SocietyData.saveMaintenanceMember(member);

                    if (isNew) {
                      SocietyData.maintenanceTeam.add(member);
                    } else {
                      SocietyData.maintenanceTeam[index] = member;
                    }

                    if (!mounted) return;
                    setState(() {});
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(isNew
                            ? '$name add ho gaya!'
                            : '$name update ho gaya!',
                            style: GoogleFonts.sora(
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ]),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                ),
              ),

              // Delete button (only for edit)
              if (!isNew) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_rounded,
                        color: AppTheme.danger, size: 18),
                    label: Text('Delete Karo',
                        style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.danger)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final id = existing?['id'] as String? ?? '';
                      if (id.isNotEmpty) {
                        await SocietyData.deleteMaintenanceMember(id);
                      }
                      setState(() {
                        SocietyData.maintenanceTeam.removeAt(index);
                      });
                    },
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = SocietyData.maintenanceTeam;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Maintenance Team',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: const Color(0xFF003D99),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showEditDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text('Add', style: GoogleFonts.sora(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: team.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.engineering_rounded, size: 44, color: AppTheme.brand),
                ),
                const SizedBox(height: 20),
                Text('No Team Members', style: GoogleFonts.sora(
                    color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Add maintenance staff below', style: GoogleFonts.sora(
                    color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text('Add Member', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                  onPressed: () => _showEditDialog(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ],
            ))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: team.length,
              itemBuilder: (_, i) {
                final m = team[i];
                final name     = m['name']     as String? ?? '';
                final position = m['position'] as String? ?? '';
                final phone    = m['phone']    as String? ?? '';
                final imageUrl = (m['imageUrl'] ?? m['imagePath'] ?? '') as String;
                final colors = [AppTheme.brand, AppTheme.success, AppTheme.gold,
                  AppTheme.danger, const Color(0xFF7B2FBE)];
                final c = colors[name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                    boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                            color: c.withOpacity(0.1),
                            border: Border.all(color: c.withOpacity(0.25), width: 1.5)),
                        child: GestureDetector(
                          onLongPress: imageUrl.isNotEmpty ? () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black87,
                              builder: (_) => GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(imageUrl,
                                          fit: BoxFit.contain, width: 300, height: 300),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(name, style: GoogleFonts.sora(
                                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                    Text(position, style: GoogleFonts.sora(
                                        color: Colors.white60, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    Text('Release to close', style: GoogleFonts.sora(
                                        color: Colors.white38, fontSize: 11)),
                                  ]),
                                ),
                              ),
                            );
                          } : null,
                          child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover, width: 64, height: 64,
                                  loadingBuilder: (_, child, progress) =>
                                      progress == null ? child
                                          : Center(child: CircularProgressIndicator(
                                              strokeWidth: 2, color: c)),
                                  errorBuilder: (_, __, ___) => Center(child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: GoogleFonts.sora(fontSize: 24,
                                          fontWeight: FontWeight.w800, color: c))))
                              : Center(child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.sora(fontSize: 24,
                                      fontWeight: FontWeight.w800, color: c))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: GoogleFonts.sora(
                            fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: c.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(position, style: GoogleFonts.sora(
                              fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Row(children: [
                            Icon(Icons.phone_rounded, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 5),
                            Text(phone, style: GoogleFonts.sora(
                                fontSize: 12, color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ])),
                      if (widget.isAdmin)
                        GestureDetector(
                          onTap: () => _showEditDialog(index: i),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.brand.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: const Icon(Icons.edit_rounded, color: AppTheme.brand, size: 18),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
      floatingActionButton: (widget.isAdmin && team.isNotEmpty) ? FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppTheme.brand,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Add Member', style: GoogleFonts.sora(
            color: Colors.white, fontWeight: FontWeight.w700)),
      ) : null,
    );
  }
}
