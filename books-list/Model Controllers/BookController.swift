//
//  BookController.swift
//  books-list
//
//  Created by De MicheliStefano on 21.08.18.
//  Copyright © 2018 De MicheliStefano. All rights reserved.
//

import Foundation
import CoreData

class BookController {
    
    // MARK: - Properties
    
    var searchedBooks: [BookRepresentation] = []
    let googleBooksBaseURL = URL(string: "https://www.googleapis.com/books/v1")!
    
    typealias CompletionHandler = (Error?) -> Void
    
    // MARK: - API Methods
    func fetchFromGoogleBooks(with searchTerm: String, completion: @escaping (Error?) -> Void) {
        let url = googleBooksBaseURL.appendingPathComponent("volumes")
        let urlComponents = NSURLComponents(url: url, resolvingAgainstBaseURL: true)
        let searchQueryItem = URLQueryItem(name: "q", value: searchTerm)
        urlComponents?.queryItems = [searchQueryItem]
        
        guard let requestURL = urlComponents?.url else {
            NSLog("Problem constructing search IRL for \(searchTerm)")
            completion(NSError())
            return
        }
        
        let request = URLRequest(url: requestURL)
        
        GoogleBooksAuthorizationClient.shared.addAuthorization(to: request) { (request, error) in
            if let error = error {
                NSLog("Error adding authorization to request: \(error)")
                completion(error)
                return
            }
            guard let request = request else { return }
            
            URLSession.shared.dataTask(with: request) { (data, _, error) in
                if let error = error {
                    NSLog("Error fetching volumes from Google Books API: \(error)")
                    completion(error)
                    return
                }
                
                guard let data = data else {
                    NSLog("Error fetching volumes")
                    completion(error)
                    return
                }
                
                do {
                    let results = try JSONDecoder().decode(BookRepresentations.self, from: data)
                    if let items = results.items {
                        let bookRepresentations = items
                        self.searchedBooks = bookRepresentations
                        completion(nil)
                    }
                    //TODO: Add information to the user that no volumes were found
                    NSLog("No volumes found")
                    completion(NSError())
                } catch {
                    NSLog("Error decoding volumes: \(error)")
                    completion(error)
                    return
                }
            }.resume()
        }
    }
    
    func fetchImageDataFromGoogleBooks(withURL url: URL, completion: @escaping (Data?, Error?) -> Void) {
        let request = URLRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            completion(data, error)
        }.resume()
    }
    
    // MARK: - Persistence Methods
    
    func create(_ bookRepresentation: BookRepresentation, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) -> Book? {
        if let book = fetchSingleBookFromPersistenceStore(forIdentifier: bookRepresentation.id) {
            return book
        } else {
            let book = Book(bookRepresentation: bookRepresentation)
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("Error saving book to persistence store: \(error)")
            }
            return book
        }
    }
    
    func createNote(with text: String, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) -> Note? {
        var note: Note?
        
        context.performAndWait {
            let newNote = Note(text: text)
            do {
                try CoreDataStack.shared.save(context: context)
                note = newNote
            } catch {
                NSLog("Error saving note to persistence store: \(error)")
                note = nil
            }
        }
        
        return note
    }
    
    func add(_ note: Note, to book: Book, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        context.performAndWait {
            book.addToNotes(note)
            
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("Error saving notes to book \(book): \(error)")
            }
        }
    }
    
    func update(_ note: Note, in book: Book, with text: String, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        context.performAndWait {
            note.text = text
            note.timestamp = Date()
            
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("Error saving notes to book \(book): \(error)")
            }
        }
    }
    
    func remove(_ note: Note, from book: Book, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        context.performAndWait {
            book.removeFromNotes(note)
            
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("Error removing notes from book \(book): \(error)")
            }
        }
    }
    
    func markAsRead(for book: Book, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        context.performAndWait {
            book.hasRead = true
            
            if let haveReadCollection = fetchSingleCollectionFromPersistentStore(forTitle: "Have read", context: context) {
                book.addToCollections(haveReadCollection)
            }
            
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("Error saving markAsRead to persistence: \(error)")
            }
        }
    }
    
    private func fetchSingleBookFromPersistenceStore(forIdentifier identifier: String, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) -> Book? {
        var book: Book?
        
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)
        
        context.performAndWait {
            do {
                book = try context.fetch(fetchRequest).first
            } catch {
                NSLog("Error fetching book from persistence store: \(error)")
                book = nil
            }
        }
        
        return book
    }
    
    private func fetchSingleCollectionFromPersistentStore(forTitle title: String, context: NSManagedObjectContext) -> Collection? {
        var collection: Collection?
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", title)
        
        context.performAndWait {
            do {
                collection = try context.fetch(fetchRequest).first
            } catch {
                NSLog("Error fetching collection from persistence store: \(error)")
                collection = nil
            }
        }
        
        return collection
    }
    
    private func fetchSingleNoteFromPersistentStore(forIdentifier identifier: String, context: NSManagedObjectContext) -> Note? {
        var note: Note?
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)
        
        context.performAndWait {
            do {
                note = try context.fetch(fetchRequest).first
            } catch {
                NSLog("Error fetching note from persistence store: \(error)")
                note = nil
            }
        }
        
        return note
    }

    // MARK: - Private Methods
    
    
}
