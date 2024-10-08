import HashMap "mo:base/HashMap";
// import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

actor FocusPeerApp {

  type User = {
    id: Text;
    username: Text;
    totalPoints: Nat;
    activeSession: ?Session; // Optional, because a user may not have an active session
  };

  type Session = {
    startTime: Time.Time;
    duration: Nat; // Duration in hours
    points: Nat;
    isActive: Bool;
  };


  // Stable arrays to store the user and product data
  stable var stableUsers: [(Text, User)] = [];
  stable var stableProducts: [(Text, Product)] = [];

  // In-memory HashMaps to store user and product data
  var users: HashMap.HashMap<Text, User> = HashMap.HashMap<Text, User>(
    10,
    func(a: Text, b: Text): Bool { a == b },
    Text.hash
  );

  var products: HashMap.HashMap<Text, Product> = HashMap.HashMap<Text, Product>(
    10,
    func(a: Text, b: Text): Bool { a == b },
    Text.hash
  );


  // Iterate over the HashMap and convert to a stable array (manually)
  system func preupgrade() {
    stableUsers := Iter.toArray(users.entries());
    stableProducts := Iter.toArray(products.entries());
  };

  // Restore the HashMap from the stable arrays
  system func postupgrade() {
    users := HashMap.HashMap<Text, User>(
      10,
      func(a: Text, b: Text): Bool { a == b },
      Text.hash
    );
    products := HashMap.HashMap<Text, Product>(
      10,
      func(a: Text, b: Text): Bool { a == b },
      Text.hash
    );

    // Manually reinsert each item into the HashMaps
    for (userPair in stableUsers.vals()) {
      users.put(userPair.0, userPair.1);
    };
    for (productPair in stableProducts.vals()) {
      products.put(productPair.0, productPair.1);
    };
  };

  // Register a new user
  public func registerUser(username: Text, userId: Text): async Text {
    // let userId = Principal.toText(Principal.fromActor(FocusPeerApp)); // Use Principal as unique ID
    let newUser: User = {
      id = userId;
      username = username;
      totalPoints = 0;
      activeSession = null;
    };
    users.put(userId, newUser);
    return userId;
  };

  // Get user details
  public query func getUser(userId: Text): async ?User {
    return users.get(userId);
  };

  // Start a session
public func startSession(userId: Text, duration: Nat): async Bool {
  let userOpt = users.get(userId);
  switch(userOpt) {
    case (null) { return false; }; // User not found
    case (?user) {
      let newSession: Session = {
        startTime = Time.now();  // Session starts now
        duration = duration;
        points = 0;  // Initially, no points
        isActive = true;
      };
      let updatedUser: User = {
        id = user.id;
        username = user.username;
        totalPoints = user.totalPoints;
        activeSession = ?newSession; 
      };
      users.put(userId, updatedUser);  // Update user in HashMap
      return true;
    };
  };
};

// End the session
public func endSession(userId: Text):  async Bool {
  let userOpt = users.get(userId);
  switch(userOpt) {
    case (null) { return false; }; // User not found
    case (?user) {
      switch(user.activeSession) {
        case (null) { return false; }; // No active session
        case (?session) {
          if (session.isActive) {
            let totalPoints = user.totalPoints + session.points;
            let updatedUser: User = {
              id = user.id;
              username = user.username;
              totalPoints = totalPoints;
              activeSession = null;  // Session is no longer active
            };
            users.put(userId, updatedUser);
            return true;
          } else {
            return false;
          };
        };
      };
    };
  };
};

// Adjust points based on phone usage
public func adjustPoints(userId: Text, isUsingPhone: Bool): async Bool {
  let userOpt = users.get(userId);
  switch(userOpt) {
    case (null) { return false; }; // User not found
    case (?user) {
      switch(user.activeSession) {
        case (null) { return false; }; // No active session
        case (?session) {
          if (session.isActive) {
            if (isUsingPhone) {
              // Decrease points
              let newPoints = if (session.points > 1) session.points - 1 else 0;
              let updatedSession: Session = { 
                startTime = session.startTime;
                duration = session.duration; // Duration in hours
                points = newPoints;
                isActive = session.isActive;
              };
              let updatedUser: User = { 
                id = user.id;
                username = user.username;
                totalPoints = user.totalPoints; 
                activeSession = ?updatedSession
               };
              users.put(userId, updatedUser);
            } else {
              // Increase points
              let updatedSession: Session = { 
                startTime = session.startTime;
                duration = session.duration;
                isActive = session.isActive;
                points = session.points + 1 
              };
              let updatedUser: User = { 
                id = user.id;
                username = user.username;
                totalPoints = user.totalPoints; 
                activeSession = ?updatedSession 
              };
              users.put(userId, updatedUser);
            };
            return true;
          } else {
            return false;
          };
        };
      };
    };
  };
};

type Product = {
  id: Text;
  name: Text;
  price: Nat;
  discount: Nat;
  discountPoints: Nat;  // Number of points needed to get a discount
  couponCodes: [Text]; 
};

public func remove(array: [Text], value: Text) : async [Text] {
    Array.filter(array, func(val: Text) : Bool { value != val });
};

// Redeem points for a discount
public func redeemPoints(userId: Text, productId: Text): async ?Text {
  let userOpt = users.get(userId);
  let productOpt = products.get(productId);

  switch (userOpt, productOpt) {
    case (?user, ?product) {
      if (user.totalPoints >= product.discountPoints) {
        let updatedUser: User = {
          id = user.id;
          username = user.username;
          totalPoints = user.totalPoints - product.discountPoints;
          activeSession = user.activeSession
        };
        users.put(userId, updatedUser);
        let couponCode = product.couponCodes[0];
        
            
        // Create a new array for the remaining coupon codes
        let updatedCouponCodes: [Text] = Array.filter(product.couponCodes, func(val: Text) : Bool {
          return couponCode != val;
        });

        
        // Update the product with the new coupon code list
        let updatedProduct: Product = {
          id = product.id;
          name = product.name;
          price = product.price;
          discount = product.discount;
          discountPoints = product.discountPoints;
          couponCodes = updatedCouponCodes;  // Use the new array without the redeemed coupon
        };
        products.put(productId, updatedProduct);

        // Return the coupon code to the user
        return ?couponCode;  // Successfully redeemed and returning coupon code
      } else {
        return null;  // Not enough points
      };
    };
    case _ { return null; };  // Either user or product not found
  };
};


public func cancelSession(userId: Text): async Bool {
  let userOpt = users.get(userId);
  switch(userOpt) {
    case (null) { return false; }; // User not found
    case (?user) {
      switch(user.activeSession) {
        case (null) { return false; }; // No active session
        case (?session) {
          let updatedUser: User = {
            id = user.id;
            username = user.username;
            totalPoints = user.totalPoints;
            activeSession = null;
          };  // Session is cancelled
          users.put(userId, updatedUser);
          return true;
        };
      };
    };
  };
};

// Create a new product
public func createProduct(productId: Text, name: Text, price: Nat, discount: Nat, discountPoints: Nat, couponCodes: [Text] ): async Text {
  let newProduct: Product = {
    id = productId;
    name = name;
    price = price;
    discount = discount;
    discountPoints = discountPoints;
    couponCodes = couponCodes; 
  };
  products.put(productId, newProduct);
  return productId; 
};

// Get product details
public query func getProduct(productId: Text): async ?Product {
  return products.get(productId);
};


}
