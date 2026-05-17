enum FriendshipState { 
  none, 
  sentPending, 
  receivedPending, 
  connected 
}

class RecommendationContext {
  final String text;
  final String? eventName;
  final int? mutualCount;

  const RecommendationContext({
    required this.text,
    this.eventName,
    this.mutualCount,
  });
}
