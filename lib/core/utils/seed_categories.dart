import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> seedCategories() async {
  final db = FirebaseFirestore.instance;
  final categoriesRef = db.collection('categories');

  final categoriesData = {
    'community': {
      'name': 'Community',
      'tags': [
        'Community', 'Festivals', 'Networking', 'Volunteering', 'Meetups', 
        'Charity', 'Tech', 'Startups', 'Support Groups', 
        'Religion', 'Spirituality', 'Gaming', 'E-Sports', 'Hackathons',
        'Afrikaans', 'isiZulu', 'isiXhosa', 'Sesotho', 'Setswana',
        'English', 'Xitsonga', 'siSwati', 'Tshivenda', 'isiNdebele',
        'Entrepreneurship', 'Mental Health', 'Book Clubs',
        'Personal Development',
        'Real Estate', 'Investing', 'Freelancing', 'Parents', 'Students', 'Alumni'
      ],
    },
    'music': {
      'name': 'Music',
      'tags': [
        'Music', 'Live Concerts', 'EDM', 'Hip-Hop', 'R&B', 'Rock', 
        'Jazz', 'Classical', 'Acoustic', 'Karaoke', 'Open Mic', 
        'DJ Sets', 'Afrobeats', 'Pop', 'Country', 'Amapiano', 'Gqom',
        'Kwaito', 'House', 'Techno', 'Reggae', 'Indie', 'Alternative',
        'Metal', 'Punk', 'Blues', 'Soul', 'Funk', 'Gospel', 'Folk',
        'Opera', 'Choirs', 'Jam Sessions', 'Instrumentals', 'Songwriting'
      ],
    },
    'films': {
      'name': 'Films',
      'tags': [
        'Films', 'Horror', 'Comedy', 'Drama', 'Action', 'Sci-Fi', 
        'Documentaries', 'Indie', 'Outdoor Cinema', 'Anime', 
        'Film Festivals', 'Thriller', 'Romance', 'Fantasy', 'Animation',
        'Short Films', 'Independent Films', 'Classics', 'Mystery', 'Crime',
        'Historical', 'Biographies', 'Directors Cut', 'Screenwriting',
        'Film Production', 'Drive-in Movies'
      ],
    },
    'arts': {
      'name': 'Arts',
      'tags': [
        'Arts', 'Exhibitions', 'Theater', 'Stand-up Comedy', 'Poetry', 
        'Painting', 'Photography', 'Fashion', 'Design', 'Workshops', 
        'Museums', 'Crafting', 'Sculpture', 'Graphic Design', 'Illustration',
        'Digital Art', 'Architecture', 'Ceramics', 'Pottery', 'Knitting',
        'Sewing', 'Calligraphy', 'Improv', 'Dance Performances', 'Ballet', 'Musicals'
      ],
    },
    'fitness': {
      'name': 'Fitness',
      'tags': [
        'Fitness', 'Running', 'Yoga', 'Gym', 'Hiking', 'Cycling', 
        'Dance', 'Martial Arts', 'Sports', 'Wellness', 'Meditation', 
        'CrossFit', 'Swimming', 'Pilates', 'Boxing', 'Soccer', 'Rugby',
        'Cricket', 'Netball', 'Tennis', 'Basketball', 'Golf', 'Surfing',
        'Skateboarding', 'Rock Climbing', 'Calisthenics', 'Aerobics',
        'Zumba', 'Marathons', 'Triathlons', 'Personal Training'
      ],
    },
    'food': {
      'name': 'Food',
      'tags': [
        'Food', 'Wine Tasting', 'Street Food', 'Fine Dining', 'Vegan', 
        'Baking', 'Coffee', 'Craft Beer', 'Cooking Classes', 
        'Food Festivals', 'Pop-ups', 'Mixology', 'BBQ', 'Braai',
        'Desserts', 'Pastries', 'Seafood', 'Sushi', 'Burgers', 'Pizza',
        'Halal', 'Kosher', 'Gluten-Free', 'Organic', 'Farmers Markets',
        'Food Trucks', 'Cocktails', 'Whiskey Tasting'
      ],
    },
    'education': {
      'name': 'Education',
      'tags': [
        'Education', 'Workshops', 'Seminars', 'Tutoring', 'Language Exchange', 
        'Coding', 'Mentorship', 'Masterclasses', 'Bootcamps', 'Study Groups', 
        'Career Fairs', 'Lectures', 'Skill Building', 'EdTech', 'Financial Literacy',
        'History', 'Science', 'Technology', 'Engineering', 'Mathematics'
      ],
    },
  };

  try {
    final batch = db.batch();
    for (final entry in categoriesData.entries) {
      final docId = entry.key;
      final data = entry.value;
      final docRef = categoriesRef.doc(docId);
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await batch.commit();
    debugPrint('Successfully seeded categories to Firestore!');
  } catch (e) {
    debugPrint('Failed to seed categories: $e');
  }
}
