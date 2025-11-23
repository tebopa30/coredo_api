Question.destroy_all
Option.destroy_all
Dish.destroy_all

q1 = Question.create!(text: "あっさり or こってり？", order_index: 1, routing: "static")
q2 = Question.create!(text: "和食？洋食？中華？", order_index: 2, routing: "static")

ramen = Dish.create!(name: "豚骨ラーメン", cuisine: "中華", heaviness: "こってり", description: "濃厚スープ")
udon  = Dish.create!(name: "ざるうどん", cuisine: "和食", heaviness: "あっさり", description: "さっぱり麺")
pasta = Dish.create!(name: "ペペロンチーノ", cuisine: "洋食", heaviness: "あっさり", description: "シンプルな味")

# Q1 options
Option.create!(question: q1, text: "あっさり", next_question_id: q2.id)
Option.create!(question: q1, text: "こってり", next_question_id: q2.id)

# Q2 options（分岐→料理）
Option.create!(question: q2, text: "和食", dish_id: udon.id)
Option.create!(question: q2, text: "洋食", dish_id: pasta.id)
Option.create!(question: q2, text: "中華", dish_id: ramen.id)
