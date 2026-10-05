import '../../core/constants/app_enums.dart';
import 'job_models.dart';
import 'teacher_profile.dart';

/// Message échange dans un espace de recrutement (§23).
class MessageItem {
  const MessageItem({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.sentAt,
    this.attachmentPath,
    this.attachmentName,
    this.masked = false,
    this.readByPeer = false,
  });

  final String id;
  final String roomId;
  final String senderId;
  final UserRole senderRole;
  final String body;
  final DateTime sentAt;
  final String? attachmentPath;
  final String? attachmentName;

  /// Le message a ete filtre par la protection anti-contournement (§30).
  final bool masked;
  final bool readByPeer;

  bool get hasAttachment => attachmentPath != null;
}

/// Entretien (§25).
class InterviewItem {
  const InterviewItem({
    required this.id,
    required this.roomId,
    required this.scheduledAt,
    required this.mode,
    required this.status,
    this.location,
    this.meetingLink,
    this.comment,
    this.feedback,
  });

  final String id;
  final String roomId;
  final DateTime scheduledAt;
  final InterviewMode mode;
  final InterviewStatus status;
  final String? location;
  final String? meetingLink;
  final String? comment;
  final String? feedback;

  bool get isUpcoming =>
      scheduledAt.isAfter(DateTime.now()) &&
      (status == InterviewStatus.proposed ||
          status == InterviewStatus.accepted);
}

/// Proposition officielle de recrutement (§26).
class OfferItem {
  const OfferItem({
    required this.id,
    required this.roomId,
    required this.position,
    required this.contractType,
    required this.monthlySalary,
    required this.startDate,
    required this.status,
    required this.sentAt,
    this.subject,
    this.levels = const [],
    this.durationMonths,
    this.trialPeriodDays,
    this.schedule,
    this.extraConditions,
    this.changeRequest,
    this.respondedAt,
  });

  final String id;
  final String roomId;
  final String position;
  final ContractType contractType;
  final int monthlySalary;
  final DateTime startDate;
  final OfferStatus status;
  final DateTime sentAt;
  final RefItem? subject;
  final List<RefItem> levels;
  final int? durationMonths;
  final int? trialPeriodDays;
  final String? schedule;
  final String? extraConditions;
  final String? changeRequest;
  final DateTime? respondedAt;

  bool get awaitsTeacher => status == OfferStatus.sent;

  /// Frais de recrutement dus a la plateforme (§36).
  int get successFee => monthlySalary;
}

/// Contrat genere a partir de l'offre acceptée (§27).
class ContractItem {
  const ContractItem({
    required this.id,
    required this.roomId,
    required this.offerId,
    required this.reference,
    required this.bodyText,
    required this.status,
    required this.createdAt,
    this.pdfPath,
    this.teacherSignaturePath,
    this.teacherSignedAt,
    this.institutionSignaturePath,
    this.institutionSignedAt,
  });

  final String id;
  final String roomId;
  final String offerId;
  final String reference;
  final String bodyText;
  final ContractStatus status;
  final DateTime createdAt;
  final String? pdfPath;
  final String? teacherSignaturePath;
  final DateTime? teacherSignedAt;
  final String? institutionSignaturePath;
  final DateTime? institutionSignedAt;

  bool get signedByTeacher => teacherSignaturePath != null;
  bool get signedByInstitution => institutionSignaturePath != null;
  bool get fullySigned => signedByTeacher && signedByInstitution;
}

/// Événement du workflow de recrutement (§28).
class RecruitmentEvent {
  const RecruitmentEvent({
    required this.id,
    required this.toStage,
    required this.createdAt,
    this.fromStage,
    this.note,
  });

  final String id;
  final RecruitmentStage toStage;
  final DateTime createdAt;
  final RecruitmentStage? fromStage;
  final String? note;
}

/// Suivi après recrutement (§32).
class RecruitmentFollowUp {
  const RecruitmentFollowUp({
    required this.id,
    required this.startDate,
    required this.active,
    required this.monthlySalary,
    required this.completedMilestones,
    this.trialPeriodDays,
    this.contractId,
    this.successFeeAmount = 0,
    this.feePaid = false,
  });

  final String id;
  final DateTime startDate;
  final bool active;
  final int monthlySalary;

  /// Jalons de suivi déjà realises : 30, 60, 90 jours.
  final List<int> completedMilestones;
  final int? trialPeriodDays;
  final String? contractId;
  final int successFeeAmount;
  final bool feePaid;

  int get daysSinceStart => DateTime.now().difference(startDate).inDays;

  /// Jalons echus mais non encore renseignes.
  List<int> dueMilestones(List<int> schedule) => [
    for (final day in schedule)
      if (daysSinceStart >= day && !completedMilestones.contains(day)) day,
  ];
}

/// Évaluation d'un enseignant par l'établissement (§32).
class TeacherReviewItem {
  const TeacherReviewItem({
    required this.id,
    required this.milestoneDays,
    required this.punctuality,
    required this.pedagogy,
    required this.subjectMastery,
    required this.professionalism,
    required this.attendance,
    required this.overall,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final int milestoneDays;
  final int punctuality;
  final int pedagogy;
  final int subjectMastery;
  final int professionalism;
  final int attendance;
  final int overall;
  final DateTime createdAt;
  final String? comment;

  /// Moyenne des critères, sur 5.
  double get average =>
      (punctuality + pedagogy + subjectMastery + professionalism + attendance) /
      5;
}

/// Espace de recrutement (§24) — centralise tout le dossier d'un candidat.
class RecruitmentRoomView {
  const RecruitmentRoomView({
    required this.id,
    required this.applicationId,
    required this.stage,
    required this.job,
    required this.teacher,
    required this.createdAt,
    this.messages = const [],
    this.interviews = const [],
    this.offer,
    this.contract,
    this.followUp,
    this.events = const [],
    this.internalNotes,
    this.unreadCount = 0,
  });

  final String id;
  final String applicationId;
  final RecruitmentStage stage;
  final JobOffer job;
  final TeacherProfile teacher;
  final DateTime createdAt;
  final List<MessageItem> messages;
  final List<InterviewItem> interviews;
  final OfferItem? offer;
  final ContractItem? contract;
  final RecruitmentFollowUp? followUp;
  final List<RecruitmentEvent> events;
  final String? internalNotes;
  final int unreadCount;

  /// Les coordonnées ne sont revelees qu'une fois le contrat signe (§30).
  bool get contactUnlocked =>
      contract?.fullySigned == true ||
      stage.order >= RecruitmentStage.contractSigned.order;

  InterviewItem? get nextInterview {
    final upcoming = interviews.where((i) => i.isUpcoming).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  MessageItem? get lastMessage => messages.isEmpty ? null : messages.last;
}
