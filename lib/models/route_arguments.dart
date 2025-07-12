class ChatWithClientsArgs {
  final String userType;
  ChatWithClientsArgs(this.userType);
}

class PaymentScreenArgs {
  final String contextType;
  final String referenceId;
  const PaymentScreenArgs({
    required this.contextType,
    required this.referenceId,
  });
}

class InvoiceScreenArgs {
  final String bookingId;
  const InvoiceScreenArgs(this.bookingId);
}

class ReportUserArgs {
  final String reportedUserId;
  final String reportedUserName;
  const ReportUserArgs({
    required this.reportedUserId,
    required this.reportedUserName,
  });
}

class PortfolioLikesArgs {
  final String photographerId;
  const PortfolioLikesArgs(this.photographerId);
}

class PhotographerTeamArgs {
  final String teamId;
  const PhotographerTeamArgs(this.teamId);
}

class GCashPaymentArgs {
  final String paymentUrl;
  final String contextType; // 'booking' or 'registration'
  final String referenceId; // bookingId or userId
  final double amount;
  final String? note;

  GCashPaymentArgs({
    required this.paymentUrl,
    required this.contextType,
    required this.referenceId,
    required this.amount,
    this.note,
  });
}
