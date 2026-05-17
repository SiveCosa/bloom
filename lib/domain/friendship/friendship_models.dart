enum FriendshipState { 
  none, 
  pending, 
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
