from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, sessionmaker
from datetime import datetime

Base = declarative_base()

class Event(Base):
    __tablename__ = 'events'

    id = Column(Integer, primary_key=True)
    event_id = Column(String, unique=True, index=True)  # Fatsoma's event ID
    name = Column(String, nullable=False)
    company = Column(String)
    company_logo_url = Column(String)
    date = Column(DateTime)
    time = Column(String)
    last_entry = Column(String)
    location = Column(String)
    city = Column(String)
    age_restriction = Column(String)
    url = Column(String)
    image_url = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    tickets = relationship("Ticket", back_populates="event", cascade="all, delete-orphan")

class Ticket(Base):
    __tablename__ = 'tickets'

    id = Column(Integer, primary_key=True)
    event_id = Column(Integer, ForeignKey('events.id'))
    ticket_type = Column(String, nullable=False)
    price = Column(Float)
    currency = Column(String, default="GBP")
    availability = Column(String)  # Available, Sold Out, etc.

    event = relationship("Event", back_populates="tickets")

# Database setup
engine = create_engine('sqlite:///fatsoma_events.db')
Base.metadata.create_all(engine)
SessionLocal = sessionmaker(bind=engine)
