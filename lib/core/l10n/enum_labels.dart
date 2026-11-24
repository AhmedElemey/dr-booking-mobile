import '../../features/family/domain/family_member.dart';
import '../../features/insurance/domain/insurance.dart';
import '../../features/payments/domain/payment.dart';
import '../../features/records/domain/patient_records.dart';
import '../../features/waiting_list/domain/waiting_entry.dart';
import 'generated/app_localizations.dart';

/// Localized names for the phase 2 enums.
extension EnumLabels on AppLocalizations {
  String relationName(FamilyRelation relation) => switch (relation) {
    FamilyRelation.child => relationChild,
    FamilyRelation.spouse => relationSpouse,
    FamilyRelation.parent => relationParent,
    FamilyRelation.sibling => relationSibling,
    FamilyRelation.other => relationOther,
  };

  String genderName(FamilyGender gender) => switch (gender) {
    FamilyGender.male => genderMale,
    FamilyGender.female => genderFemale,
  };

  String paymentStatusName(AppointmentPaymentStatus status) => switch (status) {
    AppointmentPaymentStatus.unpaid => payStatusUnpaid,
    AppointmentPaymentStatus.pending => payStatusPending,
    AppointmentPaymentStatus.paid => payStatusPaid,
    AppointmentPaymentStatus.refunded => payStatusRefunded,
    AppointmentPaymentStatus.depositPaid => payStatusDepositPaid,
  };

  String insuranceStatusName(InsuranceStatus status) => switch (status) {
    InsuranceStatus.pending => insuranceStatusPending,
    InsuranceStatus.approved => insuranceStatusApproved,
    InsuranceStatus.rejected => insuranceStatusRejected,
  };

  String waitingStatusName(WaitingStatus status) => switch (status) {
    WaitingStatus.waiting => waitingStatusWaiting,
    WaitingStatus.notified => waitingStatusNotified,
    WaitingStatus.booked => waitingStatusBooked,
    WaitingStatus.cancelled => waitingStatusCancelled,
    WaitingStatus.expired => waitingStatusExpired,
  };

  String recordKindName(RecordKind kind) => switch (kind) {
    RecordKind.note => recordKindNote,
    RecordKind.diagnosis => recordKindDiagnosis,
    RecordKind.prescription => recordKindPrescription,
    RecordKind.attachment => recordKindAttachment,
  };

  /// `For Youssef (Child)`
  String forPersonLabel(FamilyMemberRef member) =>
      forPerson(member.fullName, relationName(member.relation));
}
