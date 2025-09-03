-- EWU Library Management System - Final corrected DDL + Seed Data
-- Oracle SQL
-- Ready-to-publish: sequences, tables, constraints, triggers, indexes, + expanded sample data
-- WARNING: This will CREATE objects in the connected schema.
-- Run in a test schema first.

-- =========================
-- 1) Sequences (dedicated per table; start well above seeded IDs to avoid collision)
-- =========================
CREATE SEQUENCE seq_member_id    START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_book_id      START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_copy_id      START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_loan_id      START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_res_id       START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_txn_id       START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_publisher_id START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_author_id    START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_category_id  START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_fine_id      START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
-- =========================
-- 2) Tables (in correct order to handle FK dependencies)
-- =========================

-- Members (students, faculty, guests)
CREATE TABLE members (
  member_id    NUMBER PRIMARY KEY,
  member_code  VARCHAR2(40) UNIQUE NOT NULL,
  full_name    VARCHAR2(200) NOT NULL,
  email        VARCHAR2(200),
  phone        VARCHAR2(30),
  member_type  VARCHAR2(20) NOT NULL, -- STUDENT, FACULTY, STAFF, GUEST
  department   VARCHAR2(100),
  join_date    DATE DEFAULT SYSDATE,
  status       VARCHAR2(20) DEFAULT 'ACTIVE' -- ACTIVE, INACTIVE, SUSPENDED
);

-- Staff (library admins) - CREATED BEFORE loans TABLE
CREATE TABLE staff (
  staff_id      NUMBER PRIMARY KEY,
  username      VARCHAR2(100) UNIQUE NOT NULL,
  full_name     VARCHAR2(200) NOT NULL,
  email         VARCHAR2(200),
  phone         VARCHAR2(50),
  role          VARCHAR2(50) DEFAULT 'LIBRARIAN', -- LIBRARIAN, ADMIN, ASSISTANT
  password_hash VARCHAR2(4000) -- store hash (not plaintext)
);

-- Publishers
CREATE TABLE publishers (
  publisher_id NUMBER PRIMARY KEY,
  name         VARCHAR2(200) NOT NULL,
  address      VARCHAR2(4000),
  contact      VARCHAR2(100)
);

-- Authors
CREATE TABLE authors (
  author_id NUMBER PRIMARY KEY,
  full_name VARCHAR2(200) NOT NULL
);

-- Book categories/subjects
CREATE TABLE categories (
  category_id NUMBER PRIMARY KEY,
  name        VARCHAR2(100) UNIQUE NOT NULL,
  description VARCHAR2(1000)
);

-- Books (bibliographic record)
CREATE TABLE books (
  book_id      NUMBER PRIMARY KEY,
  isbn         VARCHAR2(20) UNIQUE,
  title        VARCHAR2(500) NOT NULL,
  publisher_id NUMBER,
  pub_year     NUMBER(4),
  category_id  NUMBER,
  description  CLOB,
  total_copies NUMBER DEFAULT 0,
  CONSTRAINT fk_books_publisher FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id),
  CONSTRAINT fk_books_category  FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Book authors (many-to-many)
CREATE TABLE book_authors (
  book_id   NUMBER NOT NULL,
  author_id NUMBER NOT NULL,
  PRIMARY KEY (book_id, author_id),
  CONSTRAINT fk_ba_book   FOREIGN KEY (book_id)   REFERENCES books(book_id)   ON DELETE CASCADE,
  CONSTRAINT fk_ba_author FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- Individual physical copies of a book
CREATE TABLE book_copies (
  copy_id      NUMBER PRIMARY KEY,
  book_id      NUMBER NOT NULL,
  copy_no      VARCHAR2(50) NOT NULL, -- e.g. "C1", barcode
  shelf_loc    VARCHAR2(100),
  status       VARCHAR2(20) DEFAULT 'AVAILABLE', -- AVAILABLE, LOANED, RESERVED, LOST, MAINTENANCE
  purchase_date DATE,
  price        NUMBER(12,2),
  CONSTRAINT fk_copy_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- Loans / Issuances
CREATE TABLE loans (
  loan_id     NUMBER PRIMARY KEY,
  copy_id     NUMBER NOT NULL,
  member_id   NUMBER NOT NULL,
  staff_id    NUMBER, -- staff who issued
  issue_date  DATE DEFAULT SYSDATE,
  due_date    DATE,
  return_date DATE,
  fine_amount NUMBER(10,2) DEFAULT 0,
  status      VARCHAR2(20) DEFAULT 'ISSUED', -- ISSUED, RETURNED, OVERDUE, LOST
  CONSTRAINT fk_loans_copy   FOREIGN KEY (copy_id)   REFERENCES book_copies(copy_id),
  CONSTRAINT fk_loans_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT fk_loans_staff  FOREIGN KEY (staff_id)  REFERENCES staff(staff_id)
);

-- Reservations / Holds
CREATE TABLE reservations (
  res_id      NUMBER PRIMARY KEY,
  copy_id     NUMBER, -- optional: hold on specific copy
  book_id     NUMBER NOT NULL, -- hold on title
  member_id   NUMBER NOT NULL,
  res_date    DATE DEFAULT SYSDATE,
  status      VARCHAR2(20) DEFAULT 'ACTIVE', -- ACTIVE, CANCELLED, FULFILLED, EXPIRED
  CONSTRAINT fk_res_book   FOREIGN KEY (book_id)   REFERENCES books(book_id),
  CONSTRAINT fk_res_copy   FOREIGN KEY (copy_id)   REFERENCES book_copies(copy_id),
  CONSTRAINT fk_res_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- Transactions (audit)
CREATE TABLE transactions (
  txn_id      NUMBER PRIMARY KEY,
  txn_type    VARCHAR2(50) NOT NULL, -- ISSUE, RETURN, RESERVE, CANCEL_RES, FINE_PAYMENT, ADD_BOOK, REMOVE_BOOK
  ref_id      NUMBER, -- link to loan_id/res_id/etc
  staff_id    NUMBER,
  member_id   NUMBER,
  txn_date    DATE DEFAULT SYSDATE,
  details     CLOB,
  CONSTRAINT fk_txn_staff  FOREIGN KEY (staff_id)  REFERENCES staff(staff_id),
  CONSTRAINT fk_txn_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- Fines (optional separate table)
CREATE TABLE fines (
  fine_id     NUMBER PRIMARY KEY,
  loan_id     NUMBER NOT NULL,
  amount      NUMBER(10,2) NOT NULL,
  assessed_on DATE DEFAULT SYSDATE,
  paid_on     DATE,
  status      VARCHAR2(20) DEFAULT 'UNPAID', -- UNPAID, PAID, WAIVED
  CONSTRAINT fk_fines_loan FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

-- =========================
-- 3) Indexes for performance
-- =========================
CREATE INDEX idx_books_title    ON books(title);
CREATE INDEX idx_books_isbn     ON books(isbn);
CREATE INDEX idx_authors_name   ON authors(full_name);
CREATE INDEX idx_categories_name ON categories(name);
CREATE INDEX idx_copies_status  ON book_copies(status);
CREATE INDEX idx_members_code   ON members(member_code);

-- =========================
-- 4) Triggers to populate PKs using sequences (only when PK not provided)
-- =========================

CREATE OR REPLACE TRIGGER trg_members_pk
BEFORE INSERT ON members
FOR EACH ROW
BEGIN
  IF :NEW.member_id IS NULL THEN
    :NEW.member_id := seq_member_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_publishers_pk
BEFORE INSERT ON publishers
FOR EACH ROW
BEGIN
  IF :NEW.publisher_id IS NULL THEN
    :NEW.publisher_id := seq_publisher_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_authors_pk
BEFORE INSERT ON authors
FOR EACH ROW
BEGIN
  IF :NEW.author_id IS NULL THEN
    :NEW.author_id := seq_author_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_categories_pk
BEFORE INSERT ON categories
FOR EACH ROW
BEGIN
  IF :NEW.category_id IS NULL THEN
    :NEW.category_id := seq_category_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_books_pk
BEFORE INSERT ON books
FOR EACH ROW
BEGIN
  IF :NEW.book_id IS NULL THEN
    :NEW.book_id := seq_book_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_copies_pk
BEFORE INSERT ON book_copies
FOR EACH ROW
BEGIN
  IF :NEW.copy_id IS NULL THEN
    :NEW.copy_id := seq_copy_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_loans_pk
BEFORE INSERT ON loans
FOR EACH ROW
BEGIN
  IF :NEW.loan_id IS NULL THEN
    :NEW.loan_id := seq_loan_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_res_pk
BEFORE INSERT ON reservations
FOR EACH ROW
BEGIN
  IF :NEW.res_id IS NULL THEN
    :NEW.res_id := seq_res_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_txn_pk
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
  IF :NEW.txn_id IS NULL THEN
    :NEW.txn_id := seq_txn_id.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_fines_pk
BEFORE INSERT ON fines
FOR EACH ROW
BEGIN
  IF :NEW.fine_id IS NULL THEN
    :NEW.fine_id := seq_fine_id.NEXTVAL;
  END IF;
END;
/

-- =========================
-- 5) Seed data (explicit IDs used so FKs are predictable)
-- =========================

-- ---------- Publishers ----------
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (1, 'O''Reilly Media', '1005 Gravenstein Highway N, Sebastopol, CA', 'info@oreilly.com');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (2, 'Pearson Education', '221B Baker Street, London', 'info@pearson.com');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (3, 'McGraw-Hill', '1221 Ave, New York, NY', 'contact@mcgrawhill.com');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (4, 'Springer', 'Tiergartenstrasse 17, Berlin', 'info@springer.com');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (5, 'Cambridge University Press', 'Cambridge, UK', 'service@cambridge.org');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (6, 'Elsevier', 'Radarweg 29, Amsterdam', 'info@elsevier.com');
INSERT INTO publishers (publisher_id, name, address, contact) VALUES (7, 'Oxford University Press', 'Great Clarendon St, Oxford', 'info@oup.com');

-- ---------- Authors ----------
INSERT INTO authors (author_id, full_name) VALUES (1, 'Brian W. Kernighan');
INSERT INTO authors (author_id, full_name) VALUES (2, 'Dennis M. Ritchie');
INSERT INTO authors (author_id, full_name) VALUES (3, 'Bjarne Stroustrup');
INSERT INTO authors (author_id, full_name) VALUES (4, 'Thomas H. Cormen');
INSERT INTO authors (author_id, full_name) VALUES (5, 'Donald E. Knuth');
INSERT INTO authors (author_id, full_name) VALUES (6, 'Abraham Silberschatz');
INSERT INTO authors (author_id, full_name) VALUES (7, 'Andrew S. Tanenbaum');
INSERT INTO authors (author_id, full_name) VALUES (8, 'Ian Goodfellow');
INSERT INTO authors (author_id, full_name) VALUES (9, 'Stuart Russell');
INSERT INTO authors (author_id, full_name) VALUES (10, 'Peter Norvig');
INSERT INTO authors (author_id, full_name) VALUES (11, 'Robert C. Martin'); -- Added for accuracy
INSERT INTO authors (author_id, full_name) VALUES (12, 'Martin Fowler'); -- Added for accuracy

-- ---------- Categories ----------
INSERT INTO categories (category_id, name, description) VALUES (1, 'Computer Science', 'General CS textbooks and references');
INSERT INTO categories (category_id, name, description) VALUES (2, 'Programming', 'Programming languages, paradigms and practice');
INSERT INTO categories (category_id, name, description) VALUES (3, 'Algorithms', 'Algorithms, complexity, and data structures');
INSERT INTO categories (category_id, name, description) VALUES (4, 'Databases', 'Relational databases, SQL, DBMS');
INSERT INTO categories (category_id, name, description) VALUES (5, 'Operating Systems', 'OS principles and design');
INSERT INTO categories (category_id, name, description) VALUES (6, 'Networking', 'Computer networks and protocols');
INSERT INTO categories (category_id, name, description) VALUES (7, 'Artificial Intelligence', 'Machine learning, AI, robotics');
INSERT INTO categories (category_id, name, description) VALUES (8, 'Software Engineering', 'SE principles, testing, and design');

-- ---------- Staff ---------- (Added before loans)
INSERT INTO staff (staff_id, username, full_name, email, phone, role, password_hash) VALUES (1, 'librarian1', 'Farzana Kabir', 'farzana@ewu.edu.bd', '01888888888', 'LIBRARIAN', 'hashed_pw_1');
INSERT INTO staff (staff_id, username, full_name, email, phone, role, password_hash) VALUES (2, 'admin1', 'Rashed Chowdhury', 'rashed@ewu.edu.bd', '01999999999', 'ADMIN', 'hashed_pw_2');
INSERT INTO staff (staff_id, username, full_name, email, phone, role, password_hash) VALUES (3, 'assistant1', 'Tania Islam', 'tania@ewu.edu.bd', '01822223333', 'ASSISTANT', 'hashed_pw_3');
INSERT INTO staff (staff_id, username, full_name, email, phone, role, password_hash) VALUES (4, 'librarian2', 'Emon Rahman', 'emon@ewu.edu.bd', '01844445555', 'LIBRARIAN', 'hashed_pw_4');

-- ---------- Books ----------
-- (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (1, '9780131103627', 'The C Programming Language', 1, 1988, 2, 'Kernighan & Ritchie classic.', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (2, '9780321563842', 'Programming: Principles and Practice Using C++', 2, 2014, 2, 'Bjarne Stroustrup''s C++ text for programmers.', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (3, '9780262033848', 'Introduction to Algorithms', 4, 2009, 3, 'Cormen, Leiserson, Rivest, Stein.', 4);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (4, '9780201633610', 'Design Patterns: Elements of Reusable Object-Oriented Software', 2, 1994, 8, 'Classic design patterns book.', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (5, '9780073523323', 'Operating System Concepts', 3, 2018, 5, 'Silberschatz, Galvin, Gagne.', 4);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (6, '9780133594140', 'Computer Networks', 5, 2013, 6, 'Tanenbaum / Data comms and networking.', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (7, '9780262033849', 'Concrete Mathematics', 6, 1994, 1, 'Concrete Mathematics text.', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (8, '9780131101630', 'The Practice of Programming', 1, 1999, 2, 'Kernighan & Pike.', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (9, '9780262046305', 'Artificial Intelligence: A Modern Approach', 5, 2020, 7, 'Russell & Norvig, leading AI textbook.', 5);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (10, '9781491954249', 'Deep Learning', 1, 2016, 7, 'Goodfellow, Bengio, Courville.', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (11, '9780132350884', 'Clean Code: A Handbook of Agile Software Craftsmanship', 2, 2008, 8, 'Robert C. Martin', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (12, '9780201485677', 'Refactoring: Improving the Design of Existing Code', 2, 1999, 8, 'Martin Fowler', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (13, '9780131103628', 'Algorithms Unlocked', 3, 2013, 3, 'Readable intro to algorithms.', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (14, '9780132778046', 'Database System Concepts', 3, 2016, 4, 'Modern DBMS concepts.', 4);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (15, '9780134093413', 'Modern Operating Systems', 3, 2014, 5, 'Tanenbaum''s modern OS book.', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (16, '9780137081073', 'Computer Architecture: A Quantitative Approach', 6, 2012, 1, 'Hennessy & Patterson', 2);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (17, '9781492078005', 'Designing Data-Intensive Applications', 6, 2017, 4, 'Data systems design patterns.', 3);
INSERT INTO books (book_id, isbn, title, publisher_id, pub_year, category_id, description, total_copies)
VALUES (18, '9780262033847', 'The Art of Computer Programming (Vol 1)', 6, 1997, 1, 'Knuth''s classic.', 1);

-- ---------- Book Authors (map book_id to author_id) ----------
INSERT INTO book_authors (book_id, author_id) VALUES (1, 1);
INSERT INTO book_authors (book_id, author_id) VALUES (1, 2);
INSERT INTO book_authors (book_id, author_id) VALUES (2, 3);
INSERT INTO book_authors (book_id, author_id) VALUES (3, 4);
INSERT INTO book_authors (book_id, author_id) VALUES (5, 6);
INSERT INTO book_authors (book_id, author_id) VALUES (6, 7);
INSERT INTO book_authors (book_id, author_id) VALUES (7, 5);
INSERT INTO book_authors (book_id, author_id) VALUES (8, 1);
INSERT INTO book_authors (book_id, author_id) VALUES (9, 9);
INSERT INTO book_authors (book_id, author_id) VALUES (9, 10);
INSERT INTO book_authors (book_id, author_id) VALUES (10, 8);
-- Corrected author mappings:
INSERT INTO book_authors (book_id, author_id) VALUES (11, 11); -- Clean Code by Robert C. Martin
INSERT INTO book_authors (book_id, author_id) VALUES (12, 12); -- Refactoring by Martin Fowler
INSERT INTO book_authors (book_id, author_id) VALUES (13, 5);
INSERT INTO book_authors (book_id, author_id) VALUES (14, 6);
INSERT INTO book_authors (book_id, author_id) VALUES (15, 7);
INSERT INTO book_authors (book_id, author_id) VALUES (16, 5);
INSERT INTO book_authors (book_id, author_id) VALUES (17, 6);
INSERT INTO book_authors (book_id, author_id) VALUES (18, 5);

-- ---------- Book Copies ----------
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (1, 1, 'C1', 'Shelf A1', 'AVAILABLE', TO_DATE('2020-01-15','YYYY-MM-DD'), 500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (2, 1, 'C2', 'Shelf A1', 'LOANED', TO_DATE('2020-01-15','YYYY-MM-DD'), 500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (3, 1, 'C3', 'Shelf A1', 'AVAILABLE', TO_DATE('2021-03-20','YYYY-MM-DD'), 450.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (4, 2, 'C1', 'Shelf B1', 'AVAILABLE', TO_DATE('2019-06-10','YYYY-MM-DD'), 900.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (5, 2, 'C2', 'Shelf B1', 'AVAILABLE', TO_DATE('2019-06-10','YYYY-MM-DD'), 900.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (6, 3, 'C1', 'Shelf C1', 'AVAILABLE', TO_DATE('2018-11-01','YYYY-MM-DD'), 1200.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (7, 3, 'C2', 'Shelf C1', 'LOANED', TO_DATE('2018-11-01','YYYY-MM-DD'), 1200.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (8, 3, 'C3', 'Shelf C1', 'AVAILABLE', TO_DATE('2021-07-07','YYYY-MM-DD'), 1150.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (9, 4, 'C1', 'Shelf D1', 'AVAILABLE', TO_DATE('2017-05-05','YYYY-MM-DD'), 600.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (10, 5, 'C1', 'Shelf E1', 'AVAILABLE', TO_DATE('2016-09-09','YYYY-MM-DD'), 800.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (11, 5, 'C2', 'Shelf E1', 'AVAILABLE', TO_DATE('2016-09-09','YYYY-MM-DD'), 800.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (12, 6, 'C1', 'Shelf F1', 'AVAILABLE', TO_DATE('2015-12-12','YYYY-MM-DD'), 750.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (13, 6, 'C2', 'Shelf F1', 'AVAILABLE', TO_DATE('2015-12-12','YYYY-MM-DD'), 750.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (14, 7, 'C1', 'Shelf G1', 'AVAILABLE', TO_DATE('2014-08-08','YYYY-MM-DD'), 500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (15, 8, 'C1', 'Shelf H1', 'AVAILABLE', TO_DATE('2013-03-03','YYYY-MM-DD'), 400.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (16, 9, 'C1', 'Shelf I1', 'LOANED', TO_DATE('2021-09-01','YYYY-MM-DD'), 1500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (17, 9, 'C2', 'Shelf I1', 'AVAILABLE', TO_DATE('2021-09-01','YYYY-MM-DD'), 1500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (18, 9, 'C3', 'Shelf I1', 'AVAILABLE', TO_DATE('2022-01-11','YYYY-MM-DD'), 1500.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (19, 10, 'C1', 'Shelf J1', 'AVAILABLE', TO_DATE('2017-10-10','YYYY-MM-DD'), 1300.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (20, 10, 'C2', 'Shelf J1', 'AVAILABLE', TO_DATE('2017-10-10','YYYY-MM-DD'), 1300.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (21, 11, 'C1', 'Shelf K1', 'AVAILABLE', TO_DATE('2014-04-04','YYYY-MM-DD'), 550.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (22, 12, 'C1', 'Shelf L1', 'AVAILABLE', TO_DATE('2012-02-02','YYYY-MM-DD'), 650.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (23, 13, 'C1', 'Shelf M1', 'AVAILABLE', TO_DATE('2019-09-09','YYYY-MM-DD'), 300.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (24, 14, 'C1', 'Shelf N1', 'AVAILABLE', TO_DATE('2018-08-08','YYYY-MM-DD'), 900.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (25, 15, 'C1', 'Shelf O1', 'AVAILABLE', TO_DATE('2016-06-06','YYYY-MM-DD'), 850.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (26, 16, 'C1', 'Shelf P1', 'AVAILABLE', TO_DATE('2012-12-12','YYYY-MM-DD'), 1400.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (27, 17, 'C1', 'Shelf Q1', 'AVAILABLE', TO_DATE('2018-04-04','YYYY-MM-DD'), 950.00);
INSERT INTO book_copies (copy_id, book_id, copy_no, shelf_loc, status, purchase_date, price) VALUES (28, 18, 'C1', 'Shelf R1', 'AVAILABLE', TO_DATE('1998-01-01','YYYY-MM-DD'), 2000.00);

-- ---------- Members ----------
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (1, 'EWU_STU_0001', 'Rahman Ankan', 'rahman.ankan@ewu.edu.bd', '01710000001', 'STUDENT', 'CSE', TO_DATE('2022-02-10','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (2, 'EWU_STU_0002', 'Sara Ahmed', 'sara.ahmed@ewu.edu.bd', '01711111111', 'STUDENT', 'EEE', TO_DATE('2021-09-01','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (3, 'EWU_STU_0003', 'Tanvir Hasan', 'tanvir.hasan@ewu.edu.bd', '01722222222', 'STUDENT', 'BBA', TO_DATE('2020-03-15','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (4, 'EWU_FAC_0001', 'Dr. Mahmud Rahman', 'mahmud.rahman@ewu.edu.bd', '01733333333', 'FACULTY', 'CSE', TO_DATE('2019-01-10','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (5, 'EWU_STU_0004', 'Nusrat Jahan', 'nusrat.jahan@ewu.edu.bd', '01744444444', 'STUDENT', 'CSE', TO_DATE('2023-02-20','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (6, 'EWU_STU_0005', 'Mizan Rahman', 'mizan.rahman@ewu.edu.bd', '01755555555', 'STUDENT', 'CSE', TO_DATE('2023-08-12','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (7, 'EWU_STF_0001', 'Library Guest', 'guest@ewu.edu.bd', '01800001111', 'GUEST', NULL, TO_DATE('2024-01-05','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (8, 'EWU_FAC_0002', 'Prof. Farida Karim', 'farida.karim@ewu.edu.bd', '01777777777', 'FACULTY', 'EEE', TO_DATE('2018-07-07','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (9, 'EWU_STU_0006', 'Arafat Hossain', 'arafat.hossain@ewu.edu.bd', '01788888888', 'STUDENT', 'CSE', TO_DATE('2022-12-12','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (10, 'EWU_STU_0007', 'Laila Sultana', 'laila.sultana@ewu.edu.bd', '01799999999', 'STUDENT', 'BBA', TO_DATE('2024-05-01','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (11, 'EWU_STU_0008', 'Shahidul Islam', 'shahidul@ewu.edu.bd', '01811112222', 'STUDENT', 'CSE', TO_DATE('2020-08-20','YYYY-MM-DD'));
INSERT INTO members (member_id, member_code, full_name, email, phone, member_type, department, join_date) VALUES (12, 'EWU_STU_0009', 'Ritu Moni', 'ritu.moni@ewu.edu.bd', '01833334444', 'STUDENT', 'CSE', TO_DATE('2021-11-11','YYYY-MM-DD'));

-- ---------- Loans ----------
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (1, 2, 2, 1, TO_DATE('2024-07-01','YYYY-MM-DD'), TO_DATE('2024-07-15','YYYY-MM-DD'), TO_DATE('2024-07-14','YYYY-MM-DD'), 0, 'RETURNED');
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (2, 7, 3, 1, TO_DATE('2024-08-01','YYYY-MM-DD'), TO_DATE('2024-08-15','YYYY-MM-DD'), NULL, 0, 'ISSUED');
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (3, 16, 4, 2, TO_DATE('2024-07-01','YYYY-MM-DD'), TO_DATE('2024-07-10','YYYY-MM-DD'), NULL, 15.00, 'OVERDUE');
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (4, 16, 1, 1, TO_DATE('2022-01-01','YYYY-MM-DD'), TO_DATE('2022-01-15','YYYY-MM-DD'), TO_DATE('2022-01-14','YYYY-MM-DD'), 0, 'RETURNED');
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (5, 17, 5, 3, TO_DATE('2024-08-15','YYYY-MM-DD'), TO_DATE('2024-08-29','YYYY-MM-DD'), NULL, 0, 'ISSUED');
INSERT INTO loans (loan_id, copy_id, member_id, staff_id, issue_date, due_date, return_date, fine_amount, status)
VALUES (6, 16, 9, 4, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-06-15','YYYY-MM-DD'), NULL, 50.00, 'OVERDUE');

-- ---------- Reservations ----------
INSERT INTO reservations (res_id, copy_id, book_id, member_id, res_date, status) VALUES (1, NULL, 3, 2, TO_DATE('2024-08-20','YYYY-MM-DD'), 'ACTIVE');
INSERT INTO reservations (res_id, copy_id, book_id, member_id, res_date, status) VALUES (2, 17, 9, 5, TO_DATE('2024-08-22','YYYY-MM-DD'), 'FULFILLED');
INSERT INTO reservations (res_id, copy_id, book_id, member_id, res_date, status) VALUES (3, NULL, 1, 11, TO_DATE('2024-08-10','YYYY-MM-DD'), 'CANCELLED');
INSERT INTO reservations (res_id, copy_id, book_id, member_id, res_date, status) VALUES (4, NULL, 10, 12, TO_DATE('2024-08-25','YYYY-MM-DD'), 'ACTIVE');
INSERT INTO reservations (res_id, copy_id, book_id, member_id, res_date, status) VALUES (5, 4, 2, 6, TO_DATE('2024-08-28','YYYY-MM-DD'), 'ACTIVE');

-- ---------- Fines ----------
INSERT INTO fines (fine_id, loan_id, amount, assessed_on, paid_on, status) VALUES (1, 3, 15.00, TO_DATE('2024-07-11','YYYY-MM-DD'), NULL, 'UNPAID');
INSERT INTO fines (fine_id, loan_id, amount, assessed_on, paid_on, status) VALUES (2, 6, 50.00, TO_DATE('2024-06-16','YYYY-MM-DD'), NULL, 'UNPAID');
INSERT INTO fines (fine_id, loan_id, amount, assessed_on, paid_on, status) VALUES (3, 1, 0.00, TO_DATE('2024-07-16','YYYY-MM-DD'), TO_DATE('2024-07-16','YYYY-MM-DD'), 'PAID');

-- ---------- Transactions (audit) ----------
INSERT INTO transactions (txn_id, txn_type, ref_id, staff_id, member_id, txn_date, details) VALUES (1, 'ISSUE', 2, 1, 3, TO_DATE('2024-08-01','YYYY-MM-DD'), 'Issued book copy 7 to member 3');
INSERT INTO transactions (txn_id, txn_type, ref_id, staff_id, member_id, txn_date, details) VALUES (2, 'RETURN', 1, 1, 2, TO_DATE('2024-07-14','YYYY-MM-DD'), 'Returned copy 2 by member 2');
INSERT INTO transactions (txn_id, txn_type, ref_id, staff_id, member_id, txn_date, details) VALUES (3, 'FINE_ASSESS', 3, 2, 4, TO_DATE('2024-07-11','YYYY-MM-DD'), 'Fine 15 assessed for overdue loan 3');

-- Final commit for sample data
COMMIT;

-- =========================
-- 6) Helpful example queries (uncomment to test)
-- =========================
-- List available copies of a book:
-- SELECT bc.copy_id, bc.copy_no, bc.shelf_loc, bc.status FROM book_copies bc WHERE bc.book_id = 3;
-- Member current loans:
-- SELECT l.* FROM loans l WHERE l.member_id = 3 AND l.status IN ('ISSUED','OVERDUE');
-- =========================
-- End of script
-- =========================