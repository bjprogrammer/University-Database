/*
Design Modifications-
1.	Changed one to many relationship between Classroom table and AVEquipment table to many to many relationship.
2.  Dropped one to many relation between UserRole and AddressType as I am keeping common options in AddressType for both Users-Student and Employee.
    Keeping such a relation adds additional confusion while assigning AddressType in Address table for students who are working also(employee) as 
	they can have same address under two categories.
3.	Kept ZipCode as NULL instead of NOT NULL(required) as some countries don't have any zipcode or other form of postal codes.
*/

--Table Creation along with creation of some functions and index(used to satisfy some constraints in tables)
CREATE TABLE Person (
	PersonID	    INT		       PRIMARY KEY     IDENTITY(1,1),
	FirstName		VARCHAR(25)    NOT NULL,
	MiddleName		VARCHAR(25),
	LastName		VARCHAR(25)	   NOT NULL,
	DateOfBirth     DATE           NOT NULL, 
    SSN             CHAR(11),              
    NTID            VARCHAR(25), 
	CHECK(SSN LIKE REPLICATE('[0-9]',3)+ '-'+ REPLICATE('[0-9]',2)+'-' + REPLICATE('[0-9]',4) AND 
	      0< CAST(DATEDIFF(YEAR,DateOfBirth,CAST(GETDATE() AS DATE)) AS INT) AND 
		  CAST(DATEDIFF(YEAR,DateOfBirth,CAST(GETDATE() AS DATE)) AS INT)<100)
);
/*
Not setting NTID as NOT NULL and Unique because if NTID is NULL then trigger(NTIDSet) will automatically generate unique NTID after insertion of 
records and update it.If NTID is set to NOT NULL then SQL will generate error before trigger is invoked. In short, NOT NULL objective is achieved
using trigger.
Age of Person (at the time of enrolling in a university) cannot be greater than 100 
*/

--Unique constraint(using index) allowing multiple null values in SSN column
CREATE UNIQUE NONCLUSTERED INDEX SSNUnique    
    ON Person(SSN)
    WHERE SSN IS NOT NULL;
GO

/*
Unique constraint(using index) allowing multiple null values in NTID column
(So that error is not generated for multipe NULL values before trigger is invoked)
*/
CREATE UNIQUE NONCLUSTERED INDEX NTIDUnique    
    ON Person(NTID)
    WHERE NTID IS NOT NULL;
GO

/*
Can't use RAND Function within another function. Gives Error-Invalid use of a side-effecting operator ‘rand’ within a function.
Workaround- Generate random no within view and get that in user defined function
*/
CREATE VIEW GetRandom AS
     SELECT RAND() AS RandomValue;
GO

CREATE FUNCTION dbo.GetRandomNo()
     RETURNS DECIMAL(2,2)
     BEGIN
         RETURN (SELECT RandomValue 
		             FROM GetRandom)
     END;
GO

--dbo.NTIDGenerator will generate unique NTID for each person based on FirstName and LastName
CREATE FUNCTION dbo.NTIDGenerator(@firstName AS VARCHAR(25),@lastName AS VARCHAR(25))
	RETURNS VARCHAR(25)
	BEGIN
		DECLARE @result VARCHAR(25)
		DECLARE @store INT
	    SET @result=SUBSTRING(@firstName,1,1)+SUBSTRING(@lastName,1,24)
		SELECT @store=(SELECT COUNT(*)
			               FROM Person
			               WHERE NTID = @result)
		WHILE (@store <> 0)
		BEGIN
		    SET @result=SUBSTRING(@firstName,1,1)+SUBSTRING(@lastName,1,FLOOR(dbo.GetRandomNo()*(19))+3) 
			            + CAST(FLOOR(dbo.GetRandomNo()*(98))+1 AS VARCHAR)
		    SELECT @store=(SELECT COUNT(*)
			                   FROM Person
			                   WHERE NTID = @result)
		END
		RETURN @result
	END;
GO

CREATE TRIGGER NTIDSet 
  ON Person AFTER INSERT AS
      SET NOCOUNT ON                 --SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
	  DECLARE @personID AS INT
	  DECLARE NTIDCursor CURSOR FOR  --Since INSERTED is a table that can contain more than one recored, so using Cursors for that.
	       SELECT PersonID 
	           FROM INSERTED         
      OPEN NTIDCursor
      FETCH NEXT FROM NTIDCursor INTO @personID 
      WHILE @@FETCH_STATUS = 0
	      BEGIN
		     IF (SELECT NTID 
			         FROM Person 
					 WHERE PersonID=@personID) IS NULL
			 BEGIN
                 UPDATE Person
                     SET NTID = dbo.NTIDGenerator(LOWER(Person.FirstName),LOWER(Person.LastName))
                     FROM INSERTED AS i
                     WHERE Person.PersonID =@personID
			 END
			 FETCH NEXT FROM NTIDCursor INTO @personID
	      END
	   CLOSE NTIDCursor
       DEALLOCATE NTIDCursor;
GO

CREATE TABLE UserRole (
	RoleID	       INT		       PRIMARY KEY     IDENTITY(1,1),
	Text		   VARCHAR(10)	   NOT NULL        UNIQUE
);

CREATE TABLE UserRoles (
	RoleID	       INT		       REFERENCES UserRole(RoleID),
    PersonID       INT	           REFERENCES Person(PersonID),
    PRIMARY KEY(RoleID, PersonID)
);

CREATE TABLE AddressType (
    AddressTypeID  INT             PRIMARY KEY     IDENTITY(1,1),
    Text		   VARCHAR(25)     NOT NULL        UNIQUE
);

CREATE TABLE Address (
    AddressID      INT             PRIMARY KEY     IDENTITY(1,1),
    PersonID       INT	           NOT NULL        REFERENCES Person(PersonID),
    Street1        VARCHAR(50)     NOT NULL,
    Street2        VARCHAR(50),
    City           VARCHAR(25)     NOT NULL        CHECK(City NOT LIKE '%[0-9!@#$%^&*()-_+=.,;:"`~{}\/|<>?]%'),
    State          VARCHAR(25)     NOT NULL        CHECK(State NOT LIKE '%[0-9!@#$%^&*()-_+=.,;:"`~{}\/|<>?]%'),
    ZipCode        VARCHAR(10)                     CHECK(ZipCode NOT LIKE '%[!@#$%^&*()-_+=.,;:"`~{}\/|<>?]%' AND LEN(ZipCode) BETWEEN 3 AND 10),
    Country        VARCHAR(25)     NOT NULL        CHECK(Country NOT LIKE '%[0-9!@#$%^&*()-_+=.,;:"`~{}\/|<>?]%'),
    AddressTypeID  INT             NOT NULL        REFERENCES AddressType(AddressTypeID)
);
/*
City, State and Country won't have any numeric or specialc characters.Zipcode can be alpha numeric and can have 3 to 10 letter/no depending on 
country.
Reference-https://en.wikipedia.org/wiki/Postal_code
*/

CREATE TABLE StudentStatus (
	StudentStatusID   INT	        PRIMARY KEY    IDENTITY(1,1),
	Text		      VARCHAR(20)   NOT NULL       UNIQUE
);

CREATE TABLE StudentAccount (
    StudentID      INT             PRIMARY KEY     REFERENCES Person(PersonID),
    StudentStatus  INT             NOT NULL        REFERENCES StudentStatus(StudentStatusID),
    Password       VARCHAR(20)     NOT NULL,
	CHECK(LEN(Password) BETWEEN 8 AND 20 AND Password LIKE '%[0-9]%' AND Password LIKE '%[A-Z]%' AND
	      Password LIKE'%[!@#$%^&*_=?]%')
);
--Password must have one uppercase character,one special character and one digit and total length between 8 and 20

CREATE TABLE College (
	CollegeID      INT	           PRIMARY KEY     IDENTITY(1,1),
	Text		   VARCHAR(50)     NOT NULL        UNIQUE
);

CREATE TABLE Program (
	ProgramID      INT	           PRIMARY KEY     IDENTITY(1,1),
	Text		   VARCHAR(50)     NOT NULL        UNIQUE
);

CREATE TABLE StudentSpecialization (
    StudentID      INT             NOT NULL        REFERENCES StudentAccount(StudentID),
	ProgramID      INT	           NOT NULL        REFERENCES Program(ProgramID),
    CollegeID      INT	           NOT NULL        REFERENCES College(CollegeID),
	IsMajor        BIT             NOT NULL        DEFAULT 1
	PRIMARY KEY(StudentID,ProgramID,CollegeID)
);

CREATE TABLE CourseInformation (
    CourseCode                     VARCHAR(5)      CHECK(LEN(CourseCode) BETWEEN 3 AND 5  AND CourseCode NOT LIKE '%[^A-Z]%'),
	CourseNo                       INT,
    CourseTitle                    VARCHAR(70)	   NOT NULL,
	CourseDescription              VARCHAR(500)    NOT NULL,
	PRIMARY KEY(CourseCode,CourseNo)
);
/*
CourseTitle is not unique as Undergraduate and Graduate courses can have same name
*/

CREATE TABLE CoursePrerequisite (
    PrerequisiteID                INT              PRIMARY KEY               IDENTITY(1,1),
	PrerequisiteCode              VARCHAR(5)       NOT NULL,
	PrerequisiteNo                INT              NOT NULL,
    CourseCode                    VARCHAR(5)       NOT NULL,
	CourseNo                      INT              NOT NULL,
	FOREIGN KEY (PrerequisiteCode,PrerequisiteNo)  REFERENCES CourseInformation(CourseCode,CourseNo),
	FOREIGN KEY (CourseCode,CourseNo) REFERENCES CourseInformation(CourseCode,CourseNo),
);

CREATE TABLE ProgramCourses (
    CourseCode                    VARCHAR(5),
	CourseNo                      INT,
	ProgramID                     INT              REFERENCES Program(ProgramID),
	FOREIGN KEY (CourseCode,CourseNo) REFERENCES CourseInformation(CourseCode,CourseNo),
	PRIMARY KEY(CourseCode,CourseNo,ProgramID)
);

CREATE TABLE Building (
	BuildingID     INT	          PRIMARY KEY      IDENTITY(1,1),
	Text		   VARCHAR(50)    NOT NULL         UNIQUE
);

CREATE TABLE ProjectorType (
	ProjectorID    INT	          PRIMARY KEY      IDENTITY(1,1),
	Text		   VARCHAR(20)    NOT NULL         UNIQUE
);

CREATE TABLE ClassRoom (
    LocationID           INT      PRIMARY KEY      IDENTITY(1,1),
	BuildingName         INT      NOT NULL         REFERENCES Building(BuildingID),
	RoomNo               INT      NOT NULL,
	SeatingCapacity      INT	  NOT NULL         CHECK(SeatingCapacity>=15 AND SeatingCapacity<=500),
	NoOfWhiteBoard       INT      NOT NULL         CHECK(NoOfWhiteBoard<=3)                             DEFAULT 1,
	ProjectorType		 INT      NOT NULL         REFERENCES ProjectorType(ProjectorID)                DEFAULT 1,
	UNIQUE(BuildingName,RoomNo)
);
--ProjectorType=1 means 'Basic Projector'

CREATE TABLE AVEquipment (
	EquipmentID    INT	          PRIMARY KEY      IDENTITY(1,1),
	EquipmentName  VARCHAR(50)    NOT NULL         UNIQUE
);

CREATE TABLE ClassRoomEquipment (
    ID                  INT       PRIMARY KEY      IDENTITY(1,1),
	LocationID          INT       NOT NULL         REFERENCES ClassRoom(LocationID),
	EquipmentID         INT       NOT NULL         REFERENCES AVEquipment(EquipmentID),
	UNIQUE(LocationID,EquipmentID)
);

CREATE TABLE ClassDays (
	DayID          INT	          PRIMARY KEY      IDENTITY(1,1),
	Text           VARCHAR(10)    NOT NULL         UNIQUE
);
GO

--dbo.SeatingCapacityCheck returns seating capacity for a particular LocationID 
CREATE FUNCTION dbo.SeatingCapacityCheck(@locationID AS INT)
	RETURNS INT
	BEGIN
		DECLARE @result INT
		SELECT @result = SeatingCapacity
			FROM ClassRoom
			WHERE LocationID = @locationID
		RETURN @result
	END;
GO

CREATE TABLE ScheduledCourses (
    CourseID       INT           PRIMARY KEY      IDENTITY(1,1),
    CourseCode     VARCHAR(5)    NOT NULL,
	CourseNo       INT           NOT NULL,
	LocationID     INT           NOT NULL         REFERENCES ClassRoom(LocationID),
	TotalSeats     INT           NOT NULL,                           
	StartDate      DATE          NOT NULL,
	EndDate        DATE          NOT NULL,
	FOREIGN KEY (CourseCode,CourseNo) REFERENCES CourseInformation(CourseCode,CourseNo),
	CHECK(DATEDIFF(Day,StartDate,EndDate)>0 AND DATEDIFF(MONTH,StartDate,EndDate)<6 AND 
	      TotalSeats<= dbo.SeatingCapacityCheck(LocationID) AND TotalSeats>=10)
);

/* 
TotalSeats for a course cannot be greater than Classroom SeatingCapacity.
Normally course duration is not more than a semester(around 5 months) 
*/

CREATE TABLE CourseClassDays (
    CourseID       INT           REFERENCES ScheduledCourses(CourseID),
	DayID          INT           REFERENCES ClassDays(DayID),
	StartTime      TIME          NOT NULL,
	EndTime        TIME          NOT NULL,
	PRIMARY KEY(CourseID,DayID),
	CHECK(DATEDIFF(MINUTE,StartTime,EndTime)>30)
);

CREATE TABLE EnrollmentStatus (
	ID             INT	         PRIMARY KEY     IDENTITY(1,1),
	Text           VARCHAR(10)   NOT NULL        UNIQUE
);

CREATE TABLE Grading (
	GradingID      INT	         PRIMARY KEY     IDENTITY(1,1),
	Text           VARCHAR(2)    NOT NULL        UNIQUE
);

--dbo.GradingStatusCheck checks whether given grade matches with enrollmentStatus or not
GO
CREATE FUNCTION dbo.GradingStatusCheck(@gradingID AS INT,@enrollmentStatusID AS INT)
	RETURNS BIT
	BEGIN
		DECLARE @result BIT
		SET @result=0
		IF ((@gradingID BETWEEN 1 AND 10) AND @enrollmentStatusID=1)
		    SET @result=1
	    ELSE IF(@gradingID IS NULL AND (@enrollmentStatusID IN (1,2,3)))
		    SET @result=1
		ELSE IF(@enrollmentStatusID=3 AND (@gradingID=10 OR @gradingID=11))
		    SET @result=1
		ELSE IF(@enrollmentStatusID=2 AND (@gradingID=10 OR @gradingID=12))
		    SET @result=1
	    RETURN @result
	END;
GO

CREATE TABLE Enrollment (
	EnrollmentID         INT	 PRIMARY KEY     IDENTITY(1,1),
	CourseID             INT     NOT NULL        REFERENCES ScheduledCourses(CourseID),
	StudentID            INT     NOT NULL        REFERENCES StudentAccount(StudentID),
	EnrollmentStatusID   INT     NOT NULL        REFERENCES EnrollmentStatus(ID),
	GradingID            INT                     REFERENCES Grading(GradingID),
	CHECK(dbo.GradingStatusCheck(GradingID,EnrollmentStatusID)=1),
	UNIQUE(CourseID,StudentID)
);

CREATE TABLE CourseInstructor (
	InstructorID         INT	 REFERENCES Person(PersonID),
	CourseID             INT     REFERENCES ScheduledCourses(CourseID),
	PRIMARY KEY(InstructorID,CourseID)
);

CREATE TABLE JobInformation  (
	JobID                INT	                  PRIMARY KEY     IDENTITY(1,1),
	Title                VARCHAR(50)              NOT NULL        UNIQUE,
	JobDescription       VARCHAR(500)             NOT NULL,
	MinPay               DECIMAL(8,2)             NOT NULL,
	MaxPay               DECIMAL(8,2)             NOT NULL,
	IsUnionJob           BIT                      NOT NULL        DEFAULT 0,
	CHECK(MaxPay>=MinPay AND MinPay>0)
);

CREATE TABLE Requirement (
	RequirementID        INT	                  PRIMARY KEY     IDENTITY(1,1),
	Description          VARCHAR(250)             NOT NULL        UNIQUE
);

CREATE TABLE RequirementForJob (
	RequirementID        INT                      NOT NULL	      REFERENCES Requirement(RequirementID),
	JobID                INT                      NOT NULL        REFERENCES JobInformation(JobID),
	PRIMARY KEY(RequirementID,JobID)
);
GO

--dbo.AnnualPayCheck returns 1 if AnnualPay is within range of MaxPay and MinPay for that job else 0
CREATE FUNCTION dbo.AnnualPayCheck(@jobID AS INT, @annualPay AS DECIMAL(8,2))
	RETURNS BIT
	BEGIN
		DECLARE @result BIT
		DECLARE @minPay DECIMAL(8,2)
		DECLARE @maxPay DECIMAL(8,2)
		SET @result=0
		SELECT @minPay=MinPay, @maxPay=MaxPay
			FROM JobInformation
			WHERE JobID = @jobID
		IF @minPay<=@annualPay AND @annualPay<= @maxPay
		    SET @result=1
		RETURN @result
	END;
GO

CREATE TABLE EmployeeJob (
	EmployeeID           INT                      NOT NULL	       REFERENCES Person(PersonID),
	JobID                INT                      NOT NULL         REFERENCES JobInformation(JobID),
	IsActive             BIT                      NOT NULL	       DEFAULT 1,
	AnnualPay            DECIMAL(8,2)             NOT NULL,
	PRIMARY KEY(EmployeeID,JobID),
	CHECK(dbo.AnnualPayCheck(JobID,AnnualPay)=1)
);

CREATE TABLE BenefitSelection (
	SelectionID          INT	                  PRIMARY KEY     IDENTITY(1,1),
	Text                 VARCHAR(10)              NOT NULL        UNIQUE
);

CREATE TABLE BenefitType (
	TypeID               INT	                  PRIMARY KEY     IDENTITY(1,1),
	Text                 VARCHAR(25)              NOT NULL        UNIQUE
);

CREATE TABLE EmployeeBenefits (
	BenefitsID           INT	                  PRIMARY KEY     IDENTITY(1,1),
	BenefitType          INT                      NOT NULL        REFERENCES BenefitType(TypeID),
	SelectionID          INT                      NOT NULL        REFERENCES BenefitSelection(SelectionID),
	Cost                 DECIMAL(7,2)             NOT NULL        CHECK(Cost>=0),
	UNIQUE(BenefitType,SelectionID)
);

CREATE TABLE JobBenefits (
	BenefitsID           INT	                  REFERENCES EmployeeBenefits(BenefitsID),
	JobID                INT,
	EmployeeID           INT,
	FOREIGN KEY (EmployeeID,JobID) REFERENCES EmployeeJob(EmployeeID,JobID),
	PRIMARY KEY(BenefitsID, JobID,EmployeeID)
);

INSERT INTO Person(FirstName,MiddleName,LastName,DateOfBirth,SSN,NTID)
    VALUES ('Peter',  'Miranda','Warner',  '1992-11-27', '104-97-7687','pwarner'),
	       ('Bobby',   NULL,    'Jasuja',  '1993-07-04', '539-80-9288','bjasuja'),
	       ('Mario',  'Richard','Mercado', '1968-05-27', '663-57-4158','mmercado'),
           ('Brendon','Pete',   'Waller',  '1987-03-19', '552-35-8419','bwaller'),
           ('Gabriel','Andrew', 'Vaughan', '1996-12-15', '172-69-7844','gvaughan'),
           ('Dallas', 'Xavier', 'Byrd',    '1970-03-18', '210-65-9216','dbyrd'),
		   ('Blanca',  NULL,    'Doyle',   '1998-01-31',  NULL,'        bdoyle'),
	       ('Tiffany','Shad',   'Mckee',   '1985-09-25', '715-18-7548','tmckee'),
	       ('Thomas', 'Wesley', 'Corner',  '1976-05-29', '713-40-6571','tcorner'),
           ('Michael', NULL,    'Sanders', '1996-10-05', '805-57-9446','msanders'),
           ('Dusan',   NULL,    'Palider', '1979-11-27', '436-80-1858','dplaider'),
           ('Kristen','Sherry', 'Flynn',   '1991-12-20',  NULL,        'kflynn'),
		   ('Steve',  'Jim',    'Jefferson','1995-02-14','565-77-1972','sjefferson'),
	       ('Patrick','Tonya',  'Farley',  '1976-06-23', '950-45-7224','pfarley'),
	       ('Dwayne', 'Billie', 'Byrd',    '1996-04-08', '322-42-3413', NULL);
/*
Keeping NTID for last record NULL as 'dbyrd' already exists in records and trigger NTIDSET will 
automaticaly update NTID to a unique value using user defined function NTIDGenerator
*/

INSERT INTO UserRole(Text)
    VALUES ('Student'),
	       ('Employee');
		   		
INSERT INTO UserRoles(PersonID,RoleID)
    VALUES (1, 1),
	       (2, 1),
		   (3, 2),
		   (4, 2),
		   (5, 1),
		   (6, 2),
		   (7, 1),
		   (8, 2),
		   (9, 2),
		   (10,1),
		   (11,2),
		   (12,1),
		   (13,1),
		   (14,2),
		   (15,1),
		   (1, 2),
		   (2, 2),
		   (10,2);

INSERT INTO AddressType(Text)
    VALUES ('Home address'),
	       ('Local address-OffCampus'),
		   ('Local address-OnCampus');					
							
INSERT INTO Address(PersonID,Street1,Street2,City,State,ZipCode,Country,AddressTypeID)
    VALUES (1, '50 Presidential Plaza',  'C Wing, APT 2',            'Syracuse','New York',      '13229',  'USA',  1),
	       (2, '312 Westcott St',        'APT 6',                    'Syracuse','New York',      '13210',  'USA',  2),
		   (2, 'B.G. 242 Scheme No. 54', 'Vijay Nagar',              'Indore',  'Madhya Pradesh','452010', 'India',1),
	       (3, '725 Irving Avenue',       NULL,                      'Syracuse','New York',      '13210',  'USA',  1),
		   (4, '555 Columbus St',        'Ground Floor-APT 1',       'Syracuse','New York',      '13209',  'USA',  1),
		   (5, '460 N Franklin Street',  'Apartment 5',              'Syracuse','New York',      '13204',  'USA',  2),
		   (5, '120 E Cullerton St',     '#205',                     'Chicago', 'Illinois',      '60616',  'USA',  1),
		   (6, '1322 Madison St',        'APT #1',                   'Syracuse','New York',      '13215',  'USA',  1),
		   (7, '4255 Lapiniere Boulevard','Suite 300',               'Toronto', 'Ontario',       'J4Z 0C7','Canada',1),
		   (7, '137 Lexington Ave',       NULL,                      'Syracuse','New York',      '13207',  'USA',  2),
		   (8, '1436 East Genesee Street ','Apartment 1',            'Syarcuse','New York',      '13225',  'USA',  1),
		   (9, '1918 East Fayette',      'Room 2',                   'Syracuse','New York',      '13201',  'USA',  1),
		   (10,'203 Maple Street',       'Room-5',                   'Syracuse','New York',      '13213',  'USA',  1),
		   (11,'431 South Beech Street', 'APT 2',                    'Syracuse','New York',      '13207',  'USA',  1),
		   (12,'Ritaj Tower',            'Dubai Investment Park-452','Dubai',   'Dubai',          NULL,    'UAE',  1),  --No ZipCode for addresses in Dubai(UAE)
		   (12,'142 N Edwards N Ave',    'APT #3',                   'Syracuse','New York',      '13206',  'USA',  2), 
		   (13,'9702 Empire Ave',        'APT #2',                   'Cleveland','Ohio',         '44108',  'USA',  1),
		   (13,'208 Merritt Ave',         NULL,                      'Syracuse','New York',      '13206',  'USA',  2),
		   (14,'122 Schiller Ave',       'Apartment-2',              'Syracuse','New York',      '13203',  'USA',  1),
		   (15,'431 Clarendon St',       'First Floor Room 3',       'Syracuse','New York',      '13210',  'USA',  3);	
		   				
/* Reference-Addresses taken from http://syracusequalityliving.com/ */

INSERT INTO StudentStatus(Text)
    VALUES ('Undergraduate'),
	       ('Graduate'),
		   ('Non-Matriculated'),
		   ('Graduated');

INSERT INTO StudentAccount(StudentID,StudentStatus,Password)
    VALUES (1, 4,'Y2j#rockz'),
	       (2, 2,'USiphone7S=$'),
		   (5, 1,'J&KArmyno1'),
		   (7, 1,'Su*cold440'),
		   (10,3,'Cuse44%2sweat'),
		   (12,2,'452@Sherryhouse'),
		   (13,1,'ebates!Jim2old'),
		   (15,1,'cFK@fnr!7j');

INSERT INTO College(Text)
    VALUES ('College of Arts and Sciences'),
	       ('College of Engineering and Computer Science'),
		   ('David B. Falk College of Sport and Human Dynamics'),
		   ('School of Information Studies'),
		   ('Martin J. Whitman School of Management'),
		   ('Maxwell School of Citizenship and Public Affairs'),
		   ('S.I. Newhouse School of Public Communications'),
		   ('College of Visual and Performing Arts'),
		   ('College of Law'),
		   ('School of Architecture');

INSERT INTO Program(Text)
    VALUES ('MA-Anthropology'),
	       ('BA-English'),
		   ('BS-Chemical Engineering'),
		   ('BS-Computer Engineering'),
		   ('BS-Child and Family Studies'),
		   ('MS-Information Management'),
		   ('BS-Accounting'),
		   ('MBA-Business Administration'),
		   ('BA-Economics'),
		   ('Phd-Mass Communications'),
		   ('BS-Architecture');

INSERT INTO StudentSpecialization(StudentID,ProgramID,CollegeID,IsMajor)
    VALUES (1, 6, 4, 1),
	       (2, 8, 5, 1),
		   (2, 7, 6, 0),
		   (5, 3, 2, 1),
		   (7, 9, 6, 1),
		   (10,5, 3, 1),
		   (12,10,7, 1),
		   (12,2, 1, 0),
		   (13,4, 9, 1),
		   (15,11,10,1);

INSERT INTO CourseInformation(CourseCode,CourseNo,CourseTitle,CourseDescription)
    VALUES ('ANT',574,'Anthropology and Physical Design',                          'Interrelationship of social and spatial organization in traditional and modern societies. Nonverbal communication: use of space, territoriality, and impact of physical design on human behavior.'),
	       ('ENG',615,'Open Poetry Workshop',                                      'Participants write original poems, receive each other’s critiques, and revise'),
		   ('ENG',716,'Second Poetry Workshop',                                    'Secondary poetry workshop in the M.F.A. program sequence.'),
		   ('CEN',573,'Principles and Design in Air Pollution Control',            'Fundamental principles of pollution control, design of control processes and equipment. Criteria for selection of control processes and equipment for gaseous and particulate pollutants.'),
		   ('CEN',600, 'Selected Topics',                                          'Exploration of a topic (to be determined) not covered by the standard curriculum but of interest to faculty and students in a particular semester.'),
		   ('CSE',581,'Introduction to Database Management Systems',               'DBMS building blocks; entity-relationship and relational models; SQL/Oracle; integrity constraints; database design; file structures; indexing; query processing; transactions and recovery; overview of object relational DBMS, data warehouses, data mining.'),
		   ('CFS',577,'Urban Families Strengths and Challenges',                   'Theoretical and empirical research on the challenges and opportunities for children and families living in urban settings. Issues of urban housing, family-community partnerships, crime, and criminal processing, health, urban diversity, and social science policies'),
		   ('CFS',638,'Child Development in the Context of Schooling',             'Exploration of some of the issues relevant to understanding the development of children in the context of schooling'),
		   ('IST',565,'Data Mining',                                               'Introduction to data mining techniques, familiarity with particular real-world applications, challenges involved in these applications, and future directions of the field. Optional hands-on experience with commercially available software packages.'),
		   ('IST',523,'Graphic Design for the Web',                                'Learn basic and advanced website design principles utilizing Adobe Photoshop and Flash, with emphasis on typography, color theory and layout. Understand and practice Flash Actionscript basics to create animation and dynamic web applications.'),
		   ('ACC',685,'Principles of Taxation',                                    'Tax planning and taxation of business transactions, such as basis, gains, losses, nontaxable exchanges, depreciation, amortization, other business deductions, and tax credits. Research and communication skills. Extra work required of graduate students.'),
		   ('ACC',736,'Strategic Cost Analysis',                                   'Contemporary cost accounting systems in relation to strategic decisions and control of various economic organizations. Emphasizing activity-based costing, activity-based management, and integrated cost systems.'),
		   ('BUA',650,'Managing Sustainability: Purpose, Principles, and Practice','Dynamics and interdependence of economic, social, and environmental systems. Sustainable management frameworks, tools, and metrics. Local, national, and international implications. Relevance of technology, ethics, law, and policy. Interdisciplinary emphasis'),
		   ('BUA',651,'Strategic Managment and the Natural Environment',           'Sustainability from firm perspective. Regulatory, international, resource, market, and social drivers of environmental strategy. Impact of sustainability-related strategies on competitive advantage and potential liability.'),
		   ('ECN',604,'Economics for Managers',                                    'Micro- and macroeconomic theory for managerial decision making. Forecasting. Not open to students seeking advanced degrees in economics.'),
		   ('ECN',705,'Mathematics for Economists',                                'A review of mathematical techniques required in economics. Calculus, matrix, algebra, difference and differential equations, and set theory. Open to economics Ph.D. and Applied Statistics masters students only. Two semesters of calculus required.'),
		   ('NEW',579,'Advanced Newspaper Editing',                                'Copy editing, headlines, visuals, design, and technology. Handling departments and special sections, editing complex copy. Significant trends in newspaper editing.'),
		   ('NEW',508,'Newspaper Editing',                                         'Preparation of copy for publication. Headline writing. Correction of copy. Evaluation of news. Condensation of news stories. News display and makeup'),
		   ('ARC',682,'Architectural Theory & Methods',                            'Introduction to architectural theory, presented as precise and distinct modes of speculation based in research. It will develop skills necessary to define, conduct, and present research work and how it informs design practice'),
		   ('ARC',641,'Introduction to Architecture',                              'An introduction to basic definitions and concepts of architecture as an intellectual and physical discipline, and as an expression of established and emerging cultural values.');

INSERT INTO CoursePrerequisite(PrerequisiteCode,PrerequisiteNo,CourseCode,CourseNo)
    VALUES ('ENG',615,'ENG',716),
	       ('CEN',573,'CEN',600),
		   ('CFS',577,'CFS',638),
		   ('ACC',685,'ACC',736),
		   ('BUA',650,'BUA',651),
		   ('ECN',604,'ECN',705),
		   ('NEW',508,'NEW',579),
		   ('ARC',641,'ARC',682);

INSERT INTO ProgramCourses(CourseCode,CourseNo,ProgramID)
    VALUES ('ANT',574,1),
	       ('ENG',615,2),
		   ('ENG',716,2),
		   ('CEN',573,3),
		   ('CEN',600,3),
		   ('CSE',581,4),
		   ('CFS',577,5),
		   ('CFS',638,5),
		   ('IST',565,6),
		   ('IST',523,6),
		   ('ACC',685,7),
		   ('ACC',736,7),
		   ('BUA',650,8),
		   ('BUA',651,8),
		   ('ECN',604,9),
		   ('ECN',705,9),
		   ('NEW',579,10),
		   ('NEW',508,10),
		   ('ARC',682,11),
		   ('ARC',641,11);

INSERT INTO Building(Text)
    VALUES ('Slocum Hall'),
		   ('Hinds Hall'),
		   ('Link Hall'),
		   ('Management Building, Whitman School'),
		   ('Maxwell Hall'),
		   ('Newhouse Communications Center'),
		   ('Life Sciences Complex'),
		   ('Shaffer Art Building'),
		   ('Marion and Watson Halls'),
		   ('Lyman C. Smith Hall');

INSERT INTO ProjectorType(Text)
    VALUES ('Basic Projector'),
	       ('Smartboard'),
		   ('No Projector');

INSERT INTO ClassRoom(BuildingName,RoomNo,SeatingCapacity,NoOfWhiteBoard,ProjectorType)
    VALUES (1, 3, 60, 1,1),
		   (2, 29,25, 1,3),
		   (3, 59,120,2,2),
           (4, 10,50, 1,1),
		   (5, 7, 180,3,2),
		   (6, 32,110,2,1),
		   (7, 41,80, 1,2),
		   (8, 24,60, 1,1),
		   (9, 4, 45, 1,1),
           (10,15,65, 1,1);

INSERT INTO AVEquipment(EquipmentName)
    VALUES ('Podium Microphone'),
	       ('Handheld Microphone'),
		   ('Flipchart'),
		   ('Audio Cassette Recording'),
		   ('Computer'),
		   ('Document Camera');

INSERT INTO ClassRoomEquipment(LocationID,EquipmentID)
    VALUES (3, 1),
		   (3, 3),
		   (3, 5),
		   (5, 3),
		   (5, 6),
		   (5, 1),
		   (10,5),
		   (6, 2),
		   (7, 3),
		   (7, 5);

INSERT INTO ClassDays(Text)
    VALUES ('Monday'),
	       ('Tuesday'),
		   ('Wednesday'),
		   ('Thursday'),
		   ('Friday');

INSERT INTO ScheduledCourses(CourseCode,CourseNo,LocationID,TotalSeats,StartDate,EndDate)
    VALUES ('ENG',716,2, 25, '2016-08-31','2016-12-23'),
		   ('CEN',573,3, 85, '2016-08-30','2016-12-22'),
		   ('CSE',581,7, 50, '2016-09-02','2016-12-23'),
		   ('CFS',577,2, 15, '2016-08-29','2016-12-21'),
		   ('IST',565,5, 150,'2016-08-30','2016-12-23'),
		   ('ACC',685,10,60, '2016-09-01','2016-12-22'),
		   ('BUA',650,6, 100,'2016-08-31','2016-12-21'),
		   ('BUA',651,9, 40, '2016-08-29','2016-12-19'),
		   ('ECN',705,1, 55, '2016-08-30','2016-12-20'),
		   ('NEW',508,4, 30, '2016-08-29','2016-12-22'),
		   ('ARC',682,8, 60, '2016-09-01','2016-12-22'),
		   ('ENG',615,2, 25, '2016-01-31','2016-5-23'),
		   ('ECN',604,1, 55, '2016-01-30','2016-5-20'),
		   ('CFS',638,2, 15, '2016-08-29','2016-12-21');

INSERT INTO CourseClassDays(CourseID,DayID,StartTime,EndTime)
    VALUES (1, 3,'08:00:00','09:30:00'),
		   (1, 5,'17:00:00','18:30:00'),
		   (2, 2,'14:00:00','15:10:00'),
		   (2, 4,'09:00:00','10:10:00'),
		   (3, 5,'08:30:00','11:00:00'),
		   (4, 1,'11:10:00','12:20:00'),
		   (4, 3,'11:10:00','12:20:00'),
		   (5, 2,'16:00:00','17:00:00'),
		   (5, 5,'10:00:00','11:0:00'),
		   (6, 4,'17:00:00','18:30:00'),
		   (7, 3,'09:00:00','12:00:00'),
		   (8, 1,'09:30:00','10:45:00'),
		   (9, 2,'14:00:00','16:30:00'),
		   (10,1,'12:45:00','15:30:00'),
		   (10,4,'08:00:00','10:45:00'),
		   (11,4,'09:00:00','11:30:00'),
		   (12,3,'08:00:00','09:30:00'),
		   (13,2,'14:00:00','16:30:00'),
		   (14,3,'13:00:00','15:00:00');

INSERT INTO EnrollmentStatus(Text)
    VALUES ('Regular'),
	       ('Audit'),
		   ('Pass/Fail');

INSERT INTO Grading(Text)
    VALUES ('A'),
	       ('A-'),
		   ('B+'),
		   ('B'),
		   ('B-'),
		   ('C+'),
		   ('C-'),
		   ('C'),
		   ('D'),
		   ('F'),
		   ('P'),
		   ('AU');

INSERT INTO Enrollment(CourseID,StudentID,EnrollmentStatusID,GradingID)
    VALUES (5, 1, 1,3),
	       (8, 2, 1,NULL),
		   (7, 2, 1,5),
		   (4, 10,1,6),
		   (14,10,1,3),
		   (13,12,1,10),
		   (3, 13,2,12),
		   (3, 5, 3,10),
		   (9, 7, 3,11),
		   (1, 12,1,2),
		   (12,7, 1,10),
		   (10,12,1,NULL);
		   
INSERT INTO CourseInstructor(InstructorID,CourseID)
    VALUES (11,3),
	       (14,7),
		   (14,8),
		   (9, 1),
		   (9, 5),
		   (3, 4);

INSERT INTO JobInformation(Title,JobDescription,MinPay,MaxPay,IsUnionJob)
    VALUES ('Adjunct Professor',                           'First 2 - 7 years on average that a professor teaches for a college is considered to be untenured(Adjunct Professor).Role at this level is to develop curriculum and program planning.Select/improve textbooks and learning materials.Evaluate students and their academic progress',         12000,55000, 1),
		   ('Research Associate',                          'Engage in research in chosen field.Collaborate with colleagues regarding their research interests.Publish in scholarly journals.Present findings and research at academic conferences',                                                                                                       13000,40000, 0),
		   ('Assistant Professor',                         'Demonstrate excellence in teaching.Show commitment to integrating coursework in the learning process.Showcase the ability to inspire, motivate, and empower students to think critically about coursework',                                                                                   46000,81000, 1),
		   ('Associate Professor',                         'Teach advanced classes.Mentor teaching assistants',                                                                                                                                                                                                                                           56000,98000, 1),
		   ('Distinguished Professor',                     'Define, evaluate and validate course objectives.Design, revise, and update courses and materials based on new developments in current events and research findings.Support faculty-student channels for dialogue',                                                                            68000,115000,1),
		   ('Commercial-Dining Service',                   'General duties include: setting up counters, salad bars, soup bars, etc.; serving customers; cleaning and preparing food; loading and operating dish washing machines; clearing and cleaning tables; disposing of trash and garbage.',                                                        30000,65000, 1),
		   ('Student Employement-Concession Carrier',      'Concessions cashiers will sell food and beverages to patrons for Carrier Dome guests',                                                                                                                                                                                                        11000,20000, 0),
		   ('Student Employment-Residential Security Aide','Primary function of the RSA is to monitor and control access at designated residence halls.',                                                                                                                                                                                                 12000,18000, 0),
		   ('Student Employment-Tutor',                    'Tutors meet in face-to-face sessions in the Stevenson Educational Center with assigned student-athletes to assist them with curriculum based content, as well as developing academic strategies and skills. Sessions will be scheduled weekly and will continue through the entire semester.',11000,25000, 0),
		   ('Accountant-Administrative Block',             'Prepares asset, liability, and capital account entries by compiling and analyzing account information. Documents financial transactions by entering account information',                                                                                                                     43000,85000, 0);

INSERT INTO Requirement(Description)
    VALUES ('Completion of mandatory pre-assignment training'),
	       ('Must be able to handle meat and dairy products'),
		   ('Adhere to all health code and University Food Service dress code policies, which states that all employees are to be clean shaven.'),
		   ('Full time student status'),
		   ('Good customer service skills'),
		   ('Tutors must have a demonstrated ability to tutor the specific subject area and must have earned at least a “B+” in the subject area'),
		   ('Exhibit effective verbal and written communication skills and inter personal skills'),
		   ('Must hold PhDs or other highest level terminal degrees (designated as acceptable by a university or college'),
		   ('Tenured Professor with 7+ years of experience');

INSERT INTO RequirementForJob(RequirementID,JobID)
    VALUES (1,8),
	       (2,6),
		   (3,6),
		   (3,7),
		   (4,7),
		   (4,8),
		   (4,9),
		   (5,7),
		   (6,9),
		   (7,9),
		   (8,1),
		   (9,3),
		   (9,4),
		   (9,5);

INSERT INTO EmployeeJob(EmployeeID,JobID,IsActive,AnnualPay)
    VALUES (11,1, 1,52000),
	       (3, 5, 1,88000),
		   (14,3, 1,65000),
		   (6, 4, 0,70000),
		   (9, 3, 1,67000),
		   (4, 6, 1,48000),
		   (8, 10,1,62000),
		   (2, 7, 1,12000),
		   (2, 8, 1,14000),
		   (4, 9, 1,13500);

INSERT INTO BenefitSelection(Text)
    VALUES ('Single'),
	       ('Family'),
		   ('Op-out');

INSERT INTO BenefitType(Text)
    VALUES ('Health Benefits'),
	       ('Vision Benefits'),
		   ('Dental Benefits');

INSERT INTO EmployeeBenefits(BenefitType,SelectionID,Cost)
    VALUES (1,1,800),
	       (1,2,2000),
		   (1,3,0),
		   (2,1,550),
		   (2,2,700),
		   (2,3,0),
		   (3,1,850),
		   (3,2,1000),
		   (3,3,0);

--Assumption No Job Benefits for Student Employment and inactive employees
INSERT INTO JobBenefits(BenefitsID,JobID,EmployeeID)
    VALUES (2,6, 4),
	       (5,6, 4),
		   (9,6, 4),
	       (3,9, 4),
		   (6,9, 4),
		   (8,9, 4),
	       (1,10,8),
		   (4,10,8),
		   (8,10,8),
		   (2,1, 11),
		   (5,1, 11),
		   (8,1, 11),
		   (1,5, 3),
		   (6,5, 3),
		   (9,5, 3),
		   (3,3, 14),
		   (6,3, 14),
		   (9,3, 14),
		   (2,3, 9),
		   (5,3, 9),
		   (7,3, 9);

GO
--This view gives list of current international students who are enrolled(not audit) in atleast one course
CREATE VIEW InternationalStudent AS
    SELECT p.FirstName + ' '+ ISNULL(SUBSTRING(p.MiddleName,1,1),'') + ' '+ p.LastName AS StudentName,a.Country AS HomeCountry,
	       CAST(DATEDIFF(YEAR,p.DateOfBirth,CAST(GETDATE() AS DATE)) AS INT) AS Age,st.Text AS StudentStatus,c.Text AS CollegeName,
		   pr.Text AS ProgramName,Count(e.CourseID) AS EnrolledCoursesCount
        FROM Person p INNER JOIN StudentAccount s
		         ON p.PersonID=s.StudentID
		     INNER JOIN StudentSpecialization sp
			     ON s.StudentID=sp.StudentID
			 INNER JOIN Address a
			     ON a.PersonID=p.PersonID
			 INNER JOIN College c
			     ON c.CollegeID=sp.CollegeID 
			 INNER JOIN Program pr
			     ON pr.ProgramID=sp.ProgramID
			 INNER JOIN StudentStatus st
			     ON st.StudentStatusID=s.StudentStatus
			 INNER JOIN ProgramCourses pc
			     ON pc.ProgramID=pr.ProgramID
		     INNER JOIN Enrollment e
			     ON e.StudentID=s.StudentID
			 INNER JOIN ScheduledCourses sc
			     ON sc.CourseNo=pc.CourseNo AND sc.CourseCode=pc.CourseCode AND sc.CourseID=e.CourseID
        WHERE sp.IsMajor=1 AND st.Text NOT LIKE 'Graduated' AND sc.EndDate> CAST(GETDATE() AS DATE) AND a.Country NOT LIKE 'USA' 
			  AND a.AddressTypeID =(SELECT AddressTypeID 
		                                FROM AddressType
		                                WHERE Text LIKE 'Home address')
			  AND e.EnrollmentStatusID IN (SELECT ID 
		                                       FROM EnrollmentStatus
		                                       WHERE Text NOT LIKE 'Audit')
        GROUP BY p.FirstName,p.MiddleName,p.LastName,a.Country,p.DateOfBirth,st.Text,c.Text,pr.Text,p.NTID;
GO  

SELECT * 
    FROM InternationalStudent;

GO
--This view gives list of students who have enrolled in advanced courses and their grade in prerequisite course
CREATE VIEW PrerequisiteGrade AS
    SELECT p.FirstName + ' '+ ISNULL(SUBSTRING(p.MiddleName,1,1),'') + ' '+ p.LastName AS StudentName,pr.Text AS ProgramName,
	       ci.CourseTitle AS AdvanceCourseName, pre.CourseTitle AS PrerequisiteCourseName,
		   CASE 
		       WHEN e.GradingID IS NULL THEN 'Enrolled'  --Enrolled means that student has taken advanced and prerequiste courses together in same semester
			   ELSE g.Text 
		   END AS PrerequisiteGrade
        FROM Person p INNER JOIN Enrollment e 
			     ON p.PersonID=e.StudentID
			 INNER JOIN ScheduledCourses sc
			     ON sc.CourseID=e.CourseID 
			 INNER JOIN CoursePrerequisite cp
			     ON sc.CourseNo=cp.CourseNo AND sc.CourseCode=cp.CourseCode
		     INNER JOIN CourseInformation ci
			     ON cp.CourseCode=ci.CourseCode AND cp.CourseNo=ci.CourseNo
			 INNER JOIN CourseInformation pre
			     ON cp.PrerequisiteCode=pre.CourseCode AND cp.PrerequisiteNo=pre.CourseNo
		     INNER JOIN ProgramCourses pc 
			     ON pc.CourseCode= ci.CourseCode AND pc.CourseNo=ci.CourseNo 
			 INNER JOIN Program pr	 
				 ON pr.ProgramID=pc.ProgramID
			 LEFT OUTER JOIN Grading g 
			     ON g.GradingID=e.GradingID ;
GO

SELECT * 
    FROM PrerequisiteGrade;

GO
--This view gives information related to scheduled courses(ongoing and not completed yet)
CREATE VIEW CourseSchedule AS
    SELECT sc.CourseCode + '-' + CAST(sc.CourseNo AS VARCHAR) AS CourseID,c.CourseTitle,sc.TotalSeats-(SELECT COUNT(*)
	                                                                                                       FROM Enrollment 
																						                   WHERE CourseID=ci.CourseID) AS AvailableSeats,
	       CASE 
		       WHEN ci.InstructorID IS NULL THEN 'Staff'                                        
			   ELSE p.FirstName +' '+ ISNULL(SUBSTRING(p.MiddleName,1,1),'') +' '+ p.LastName 
		   END AS InstructorName,
	       c.CourseDescription,pr.Text AS ProgramName, b.Text+' Room-'+CAST(cr.RoomNo AS VARCHAR)AS Location
        FROM Person p INNER JOIN CourseInstructor ci 
			     ON p.PersonID=ci.InstructorID
			 RIGHT OUTER JOIN ScheduledCourses sc
			     ON sc.CourseID=ci.CourseID 
			 INNER JOIN ClassRoom cr
			     ON sc.LocationID=cr.LocationID 
		     INNER JOIN Building b
			     ON cr.BuildingName=b.BuildingID 
			 INNER JOIN CourseInformation c
			     ON sc.CourseCode=c.CourseCode AND sc.CourseNo=c.CourseNo
		     INNER JOIN ProgramCourses pc 
			     ON pc.CourseCode= c.CourseCode AND pc.CourseNo=c.CourseNo 
			 INNER JOIN Program pr	 
				 ON pr.ProgramID=pc.ProgramID
		 WHERE sc.EndDate>CAST(GETDATE() AS DATE);
GO

SELECT * 
    FROM CourseSchedule;

GO
--This view gives information related to wages and taxes of employees(active)
CREATE VIEW EmployeeAndTaxes AS
    SELECT EmployeeName,SSN,JobCount,TotalPay,TotalBenefitsCost,GrossIncome,CONVERT(NUMERIC(8,2),FederalIncomeTax) AS FederalIncomeTax,GrossIncome-FederalIncomeTax AS NetIncome
	    FROM
             (SELECT p.FirstName +' '+ ISNULL(SUBSTRING(p.MiddleName,1,1),'') +' '+ p.LastName AS EmployeeName,p.SSN,
	                 COUNT(e.JobID) AS JobCount,SUM(e.AnnualPay) AS TotalPay,ISNULL(BenefitsCost,0) AS TotalBenefitsCost,
				     SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) AS GrossIncome,
			         CASE 
		                 WHEN SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) BETWEEN 0 AND  9225 THEN (0.10*(SUM(e.AnnualPay)+ISNULL(BenefitsCost,0)))
			             WHEN SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) BETWEEN 9226 AND 37450 THEN 922.5+(0.15*(SUM(e.AnnualPay)+ISNULL(BenefitsCost,0)-9225))
			             WHEN SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) BETWEEN 37451 AND 90750 THEN 5156.25+(0.25*(SUM(e.AnnualPay)+ISNULL(BenefitsCost,0)-5156.25))
			             WHEN SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) BETWEEN 90751 AND 189300  THEN 18481.25+(0.10*(SUM(e.AnnualPay)+ISNULL(BenefitsCost,0)-18481.25))
			             WHEN SUM(e.AnnualPay)+ISNULL(BenefitsCost,0) BETWEEN 189301 AND 411500 THEN 46075.25+(0.10*(SUM(e.AnnualPay)+ISNULL(BenefitsCost,0)-46075.25))
		             END AS FederalIncomeTax
                  FROM Person p INNER JOIN EmployeeJob e
			               ON p.PersonID=e.EmployeeID
					   LEFT OUTER JOIN (SELECT SUM(eb.Cost) AS BenefitsCost,jb.EmployeeID
					                         FROM EmployeeBenefits eb,JobBenefits jb
						                     WHERE eb.BenefitsID=jb.BenefitsID
											 GROUP BY jb.EmployeeID)tmp 
			               ON e.EmployeeID=tmp.EmployeeID
		          WHERE e.IsActive=1
				  GROUP BY p.FirstName,p.MiddleName,p.LastName,p.SSN,tmp.BenefitsCost)tp;
Go

SELECT *
    FROM EmployeeAndTaxes;

GO

/*
  This stored procedure enrolls student in a course after checking all possible constraints.(Assuming starting date to enroll in class is
  2 months before satrt date and deadline to enroll in class is 2.5 months before end date
*/
CREATE PROCEDURE dbo.EnrollInCourse(@courseCode AS VARCHAR(5),@courseNo AS INT,@studentID AS INT,@semester AS VARCHAR(10),@year AS SMALLINT)
AS
    DECLARE @courseTitle VARCHAR(50)
    SELECT @courseTitle=(SELECT TOP 1 CourseTitle                          --Check whether any such course exists or not
                             FROM CourseInformation
                             WHERE CourseCode=@courseCode AND CourseNo=@courseNo)
	IF @courseTitle IS NOT NULL
        BEGIN
		    DECLARE @startMonth INT
			DECLARE @endMonth INT
			DECLARE @courseSemester VARCHAR(10)
			DECLARE @courseID INT
			DECLARE SemesterCursor CURSOR FOR
	        SELECT MONTH(StartDate),MONTH(EndDate),CourseID                --Check whether that course is being offered in semester specified or not
                FROM ScheduledCourses        
                WHERE CourseCode=@courseCode AND CourseNo=@courseNo AND YEAR(StartDate)=@year
            OPEN SemesterCursor
            FETCH NEXT FROM SemesterCursor INTO @startMonth, @endMonth,@courseID
			WHILE @@FETCH_STATUS=0
	            BEGIN      
			        SELECT @courseSemester=
			            CASE
			                WHEN @startMonth=1 AND @endMonth IN (4,5) THEN 'spring'
				            WHEN @startMonth IN (8,9) AND @endMonth =12 THEN 'fall'
					        WHEN @startMonth =5 AND @endMonth =8 THEN 'summer'
				        END
			        IF @courseSemester=LOWER(@semester)
                        BEGIN
				             IF EXISTS (SELECT *                              --Check whether studentid is valid or not
					                        FROM StudentAccount
								            WHERE StudentID=@studentID AND StudentStatus NOT IN (SELECT StudentStatusID
									                                                                 FROM StudentStatus
																					                 WHERE Text Like 'Graduated'))
				                 BEGIN                
	                                 DECLARE @programID INT
	                                 SELECT TOP 1 @programID=ProgramID         --Check whether course program is related to student specialization or not
                                         FROM ProgramCourses 
                                         WHERE CourseCode=@courseCode AND CourseNo=@courseNo 
	                                 IF @programID IN(SELECT ProgramID 
					                                      FROM StudentSpecialization
												          WHERE StudentID=@studentID)
                                         BEGIN  
								             IF EXISTS(SELECT *                 --Check whether deadline to enroll in course is passed or not.Also checks whether course registration started or not
                                                           FROM ScheduledCourses        
                                                           WHERE CourseID=@courseID
						                                         AND DATEDIFF(DAY,GETDATE(),EndDate)>75 AND 60>DATEDIFF(DAY,GETDATE(),StartDate))
									             BEGIN
									                 IF EXISTS (SELECT *           --Check whether student is already enrolled in course or not
					                                                FROM Enrollment
								                                    WHERE StudentID=@studentID AND CourseID=@courseID)
												          BEGIN
										                      PRINT 'Error:Student already registered for this course'
															  CLOSE SemesterCursor
                                                              DEALLOCATE SemesterCursor
                                                              RETURN
										                  END
											          ELSE
													      BEGIN
														       
															   INSERT INTO Enrollment(CourseID,StudentID,EnrollmentStatusID,GradingID)
                                                                   VALUES (@courseID,@studentID,1,NULL);
															   PRINT 'Student Successully registered for the course'
															   CLOSE SemesterCursor
                                                               DEALLOCATE SemesterCursor
															   RETURN
														  END
									    END
									ELSE 
									    BEGIN
										     PRINT 'Error:Deadline for enrolling in '+ @courseTitle+ ' has passed,please contact your department'
                                             CLOSE SemesterCursor
                                             DEALLOCATE SemesterCursor
											 RETURN
										END
	                            END
	                        ELSE 
	                            BEGIN
		                            PRINT 'Error:'+ @courseCode+'-'+CAST(@courseNo AS VARCHAR)+ ' is not related to your major/minor program(s).For enrolling in this course,please contact your department'
								    CLOSE SemesterCursor
                                    DEALLOCATE SemesterCursor
                                    RETURN
	                            END
	                    END 
                    ELSE 
                        BEGIN
						    PRINT 'Invalid StudentID'
							CLOSE SemesterCursor
                            DEALLOCATE SemesterCursor
                            RETURN
	                    END	
                END
            ELSE
                BEGIN
                    PRINT 'Sorry! This course-'+@courseTitle+' is not being offered in this semester'
					CLOSE SemesterCursor
                    DEALLOCATE SemesterCursor
					RETURN
                END
		    FETCH NEXT FROM SemesterCursor INTO @startMonth, @endMonth, @courseID
	        END
	        CLOSE SemesterCursor
            DEALLOCATE SemesterCursor
         END
	ELSE
	     BEGIN
		     PRINT 'No such course exists.Please check your Course code and Course no again'
             RETURN
		 END;
GO

EXEC dbo.EnrollInCourse @courseCode='BUA', @courseNo=651, @studentID= 2,@semester ='Fall',@year=2016;

GO

--This stored procedure assigns grades to student after checking all possible constraints.
CREATE PROCEDURE dbo.GradingStudent(@instructorId AS INT, @CourseId AS INT, @studentId AS INT, @grading AS VARCHAR(2))
AS
	BEGIN TRAN
	DECLARE @gradingID AS INT
	SELECT @gradingID=GradingID 
	    FROM Grading
		WHERE Text LIKE @grading
	DECLARE @enrollmentStatusID AS INT
	IF NOT EXISTS(SELECT CourseCode,CourseNo                                       --Check whether any such course exists or not
	                  FROM ScheduledCourses
				      WHERE CourseID=@CourseId)
	    BEGIN
		    PRINT 'Error: No such course exists .Please check the courseID again.'
			GOTO PROBLEM
		END
    IF @instructorId NOT IN(SELECT InstructorID                                    --Check whether this faculty teaches this course or not
                                 FROM CourseInstructor 
                                 WHERE CourseId=@courseId)                                                       
	    BEGIN
		    PRINT 'Error: You are not allowed to assign grades for this course.';
		    GOTO PROBLEM
	    END
	 SELECT @enrollmentStatusID=EnrollmentStatusID                                 --Check whether student has enrolled in this course or not
         FROM Enrollment
         WHERE CourseId=@courseId AND StudentID=@studentId
     IF @enrollmentStatusID IS NULL
	     BEGIN
		     PRINT 'Error: Student not enrolled in this course';
		     GOTO PROBLEM
		 END
     ELSE
	     BEGIN
		    UPDATE Enrollment
		        SET GradingID = @gradingID
		        WHERE CourseId = @courseId AND StudentID=@studentID

		     DECLARE @result BIT
		     SET @result=0
		     IF ((@gradingID BETWEEN 1 AND 10) AND @enrollmentStatusID=1)
		          SET @result=1
	         ELSE IF(@gradingID IS NULL AND (@enrollmentStatusID IN (1,2,3)))
		          SET @result=1
		     ELSE IF(@enrollmentStatusID=3 AND (@gradingID=10 OR @gradingID=11))
		          SET @result=1  
		     ELSE IF(@enrollmentStatusID=2 AND (@gradingID=10 OR @gradingID=12))
		          SET @result=1                                                 --Checks whether given grade matches with enrollmentStatus or not
   
		     IF @result=0 
			    BEGIN
		           PRINT 'Error: Student grade and Enrollment Status do not match';
		           GOTO PROBLEM
				END
		     ELSE
			   BEGIN
			       COMMIT TRAN
		           PRINT 'Success-New Grade assigned'
				   RETURN
			   END
       END
PROBLEM:   
	ROLLBACK TRAN 
	PRINT 'Transaction was rolled back'
    RETURN;

GO

EXEC dbo.GradingStudent @instructorId=14, @CourseId=8, @studentId=2, @grading='A-';

GO
--This function returns GPA of a student in a particular program(Assuming each course is of 3 credits)
CREATE FUNCTION dbo.CalculateGPA(@studentID AS INT, @programName AS VARCHAR(50))
    RETURNS DECIMAL(3,2) AS
    BEGIN
        DECLARE @gradePoints DECIMAL(4,2)
		DECLARE @GPA DECIMAL(3,2)
		SET @GPA=0
		DECLARE @sumOfGradePoints DECIMAL(4,2)
        DECLARE @gradeCount INT
		DECLARE @totalCredits INT
		DECLARE @programID INT
		SELECT @programID=ProgramID                                     --Check whether program exists or not
		    FROM Program
			WHERE Text=@programName
		IF @programID IS NULL
		    BEGIN
	           RETURN -1
	        END
		IF EXISTS (SELECT *                                             --Check whether studentid is valid or not
					   FROM StudentAccount
		               WHERE StudentID=@studentID)
		   BEGIN
		       IF @programID IN (SELECT ProgramID                       --Check whether student has enrolled in program or not
					                 FROM StudentSpecialization
		                             WHERE StudentID=@studentID)
				  BEGIN    
		              DECLARE @courseID INT
					  DECLARE GPACursor CURSOR FOR
	                     SELECT CourseID
		                     FROM ProgramCourses pc,ScheduledCourses sc
	                         WHERE pc.CourseCode=sc.CourseCode AND pc.CourseNo=sc.CourseNo AND ProgramID=@programID
                      OPEN GPACursor
                      FETCH NEXT FROM GPACursor INTO @courseID
	                  SET @sumOfGradePoints=0
	                  SET @gradeCount=0
                      WHILE @@FETCH_STATUS = 0
	                     BEGIN
						     DECLARE @gradingID INT
							 DECLARE @enrollmentStatusID INT
						     SELECT @gradingID=GradingID,@enrollmentStatusID=EnrollmentStatusID 
							     FROM Enrollment 
								 WHERE StudentID=@studentID AND CourseID=@courseID 
							 IF @gradingID IS NOT NULL AND @enrollmentStatusID=(SELECT ID                --Check whether enrolled course grade is assigned or not
							                                                        FROM EnrollmentStatus
																					WHERE Text='Regular')
							    BEGIN
								    DECLARE @grading VARCHAR(2)
									SELECT @grading=Text 
									    FROM Grading
										WHERE GradingID=@gradingID
							        SELECT @gradePoints=
									    CASE
									        WHEN @grading LIKE 'A'  THEN 4.00
										    WHEN @grading LIKE 'A-' THEN 3.67
                                            WHEN @grading LIKE 'B+' THEN 3.33
										    WHEN @grading LIKE 'B'  THEN 3.00
										    WHEN @grading LIKE 'B-' THEN 2.67
										    WHEN @grading LIKE 'C+' THEN 2.33
										    WHEN @grading LIKE 'C-' THEN 2.00
										    WHEN @grading LIKE 'C'  THEN 1.67
										    WHEN @grading LIKE 'D'  THEN 1.00
										    WHEN @grading LIKE 'F'  THEN 0.00
								       END
							      SET @gradePoints=(3*@gradePoints)
		                          SET @sumOfGradePoints=@sumOfGradePoints+@gradePoints
		                          SET @gradeCount=@gradeCount+1
		                          FETCH NEXT FROM GPACursor INTO @courseID
	                          END
					     END
	                 CLOSE GPACursor 
                     DEALLOCATE GPACursor
                     SET @totalCredits=(3*@gradeCount)
	                 SET @GPA= @sumOfGradePoints/@totalCredits   
			      END
			  ELSE
			      BEGIN
				      CLOSE GPACursor 
                      DEALLOCATE GPACursor
	                  RETURN -1
				  END
		  END
      ELSE
	      BEGIN
		      CLOSE GPACursor 
              DEALLOCATE GPACursor
	          RETURN -1
	      END
	  RETURN @GPA
	END;
GO

SELECT dbo.CalculateGPA(2,'MBA-Business Administration');


