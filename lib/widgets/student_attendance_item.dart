import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentAttendanceItem extends StatelessWidget {
  final Map<String, dynamic> attendee;
  
  const StudentAttendanceItem({
    Key? key,
    required this.attendee,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentId = attendee['studentId'] ?? '';
    final markedAt = (attendee['markedAt'] as Timestamp).toDate();
    final verificationMethod = attendee['verificationMethod'] ?? 'Manual';
    final wifiVerified = attendee['wifiVerified'] ?? false;
    
    return FutureBuilder<DocumentSnapshot>(
      future: (attendee['studentName'] == null || 
               attendee['studentName'].toString().isEmpty || 
               attendee['studentName'] == 'Unknown Student')
          ? FirebaseFirestore.instance.collection('users').doc(studentId).get()
          : null,
      builder: (context, snapshot) {
        // Get student name from attendee record or Firestore
        String studentName = attendee['studentName'] ?? 'Unknown Student';
        
        // If we have data from Firestore and the name was missing, use that instead
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null && userData['fullName'] != null) {
            studentName = userData['fullName'];
          }
        }
        
        // Get the first letter for the avatar
        String avatarText = studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                avatarText,
                style: GoogleFonts.poppins(
                  color: theme.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'ID: $studentId',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (wifiVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi,
                          color: Colors.blue.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'WiFi',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        verificationMethod,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.green.shade600,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(markedAt),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.green.shade600,
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
