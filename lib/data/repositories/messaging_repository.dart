import '../models/carousel_item_model.dart';
import '../models/message_model.dart';

abstract class MessagingRepository {
  Future<List<CarouselItem>> getCarouselItems();
  Future<List<Message>> getLatestMessages();
}

class MockMessagingRepository implements MessagingRepository {
  @override
  Future<List<CarouselItem>> getCarouselItems() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      CarouselItem(
        id: 'c1',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&auto=format&fit=crop&q=60',
        title: 'Welcome to our Community',
      ),
      CarouselItem(
        id: 'c2',
        imageUrl: 'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=800&auto=format&fit=crop&q=60',
        title: 'Grow Together in Fellowship',
      ),
      CarouselItem(
        id: 'c3',
        imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=60',
        title: 'Caring for Our Environment',
      ),
    ];
  }

  @override
  Future<List<Message>> getLatestMessages() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      Message(
        id: 'm1',
        title: 'Tafseer ul Quran Sessions',
        shortDescription: 'Tafseer ul Qurans with Mufti Mahad is held every Friday. Session starts at 8:00 p.m., after Salat ul Maghrib.',
        content: 'We are pleased to invite you to our weekly Tafseer ul Quran session with Mufti Mahad. The sessions are held every Friday evening immediately following Salat ul Maghrib, beginning around 8:00 p.m. These sessions focus on understanding the depths of Quranic verses, context, and practical lessons for our daily lives. All community members are encouraged to attend.',
        date: DateTime(2026, 2, 18),
        imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&auto=format&fit=crop&q=60',
      ),
      Message(
        id: 'm2',
        title: 'Masjid WhatsApp Group Signup',
        shortDescription: 'PLEASE SEND A SMS TO (805) 304-5940 to be included in the Masjid\'s WhatsApp Group.',
        content: 'To stay updated with the latest community announcements, prayer timing updates, and upcoming events, please join our official Masjid WhatsApp Group. To be added, simply send a text SMS message with your name to (805) 304-5940, and our admin team will include you in the list. Thank you for your continued connection!',
        date: DateTime(2026, 2, 18),
        imageUrl: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&auto=format&fit=crop&q=60',
      ),
      Message(
        id: 'm3',
        title: 'Jumma Salaat Iqama Notice',
        shortDescription: 'IQAMA FOR JUMMA SALAAT IS AT 1:40 PM. PLEASE ARRIVE EARLY.',
        content: 'Please note that the Iqama for our weekly Jumma Salaat (Friday prayer) is scheduled for 1:40 PM. We request all attendees to arrive early to secure space and listen to the Khutbah (sermon) in its entirety. Parking can be busy, so please carpool if possible and park responsibly.',
        date: DateTime(2025, 5, 16),
        imageUrl: 'https://images.unsplash.com/photo-1443674900473-117c7ad9d5be?w=800&auto=format&fit=crop&q=60',
      ),
    ];
  }
}
