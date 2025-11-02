"""
Organizer Matcher - Categorizes organizers as clubs or event companies
Uses fuzzy string matching to determine if location and company are the same entity
"""
from difflib import SequenceMatcher
import re


class OrganizerMatcher:
    """Matches and categorizes event organizers"""

    # Known club keywords that help identify club events
    CLUB_KEYWORDS = [
        'club', 'nightclub', 'bar', 'lounge', 'venue', 'space',
        'warehouse', 'loft', 'basement', 'room', 'hall'
    ]

    # Known event company keywords
    EVENT_COMPANY_KEYWORDS = [
        'events', 'productions', 'presents', 'entertainment',
        'promotions', 'music', 'collective', 'crew'
    ]

    def __init__(self, similarity_threshold: float = 0.75):
        """
        Args:
            similarity_threshold: Minimum similarity score (0-1) to consider a match
        """
        self.similarity_threshold = similarity_threshold

    def normalize_name(self, name: str) -> str:
        """Normalize a name for comparison"""
        if not name:
            return ""

        # Convert to lowercase
        name = name.lower().strip()

        # Remove common suffixes/prefixes
        name = re.sub(r'\b(the|a|an)\b', '', name)

        # Remove special characters but keep spaces
        name = re.sub(r'[^a-z0-9\s]', '', name)

        # Remove extra spaces
        name = ' '.join(name.split())

        return name

    def calculate_similarity(self, str1: str, str2: str) -> float:
        """Calculate similarity between two strings (0-1)"""
        norm1 = self.normalize_name(str1)
        norm2 = self.normalize_name(str2)

        if not norm1 or not norm2:
            return 0.0

        # Calculate base similarity
        similarity = SequenceMatcher(None, norm1, norm2).ratio()

        # Check if one contains the other (partial match bonus)
        if norm1 in norm2 or norm2 in norm1:
            similarity = max(similarity, 0.85)

        return similarity

    def is_club_keywords(self, name: str) -> bool:
        """Check if name contains club-related keywords"""
        name_lower = name.lower()
        return any(keyword in name_lower for keyword in self.CLUB_KEYWORDS)

    def is_event_company_keywords(self, name: str) -> bool:
        """Check if name contains event company keywords"""
        name_lower = name.lower()
        return any(keyword in name_lower for keyword in self.EVENT_COMPANY_KEYWORDS)

    def categorize_organizer(self, company: str, location: str) -> tuple[str, float]:
        """
        Categorize an organizer as 'club' or 'event_company'

        Args:
            company: The organizer/brand name
            location: The venue name

        Returns:
            tuple: (category: 'club'|'event_company', confidence: 0-1)
        """
        # Calculate similarity
        similarity = self.calculate_similarity(company, location)

        # High similarity = likely a club hosting their own event
        if similarity >= self.similarity_threshold:
            return ('club', similarity)

        # Check for keyword hints
        company_has_club_keywords = self.is_club_keywords(company)
        company_has_event_keywords = self.is_event_company_keywords(company)
        location_has_club_keywords = self.is_club_keywords(location)

        # If company has event keywords and location has club keywords = event company
        if company_has_event_keywords and location_has_club_keywords:
            return ('event_company', 0.9)

        # If company has club keywords and matches location somewhat = club
        if company_has_club_keywords and similarity > 0.5:
            return ('club', 0.8)

        # Medium similarity with club context = probably club
        if similarity >= 0.5 and (company_has_club_keywords or location_has_club_keywords):
            return ('club', similarity + 0.1)

        # Default: if similarity is low, it's likely an event company
        return ('event_company', 1.0 - similarity)

    def get_organizer_info(self, company: str, location: str) -> dict:
        """
        Get full organizer information

        Returns:
            dict: {
                'name': str,
                'type': 'club'|'event_company',
                'location': str,
                'confidence': float
            }
        """
        org_type, confidence = self.categorize_organizer(company, location)

        return {
            'name': company,
            'type': org_type,
            'location': location if org_type == 'club' else None,
            'confidence': confidence
        }


# Test cases
if __name__ == "__main__":
    matcher = OrganizerMatcher()

    test_cases = [
        ("Ink", "Ink"),  # Should be club
        ("Fabric", "Fabric London"),  # Should be club
        ("Ministry Of Sound", "Ministry of Sound"),  # Should be club
        ("MADE Events", "Fabric"),  # Should be event_company
        ("Outworks Events", "The Palais"),  # Should be event_company
        ("Printworks", "Printworks London"),  # Should be club
        ("Do Not Sleep", "Amnesia"),  # Should be event_company
        ("Circoloco", "DC10"),  # Should be event_company
        ("Boiler Room", "Various Venues"),  # Should be event_company
    ]

    print("=" * 70)
    print("ORGANIZER CATEGORIZATION TESTS")
    print("=" * 70)

    for company, location in test_cases:
        result = matcher.get_organizer_info(company, location)
        print(f"\n{company} @ {location}")
        print(f"  → Type: {result['type'].upper()}")
        print(f"  → Confidence: {result['confidence']:.2%}")
