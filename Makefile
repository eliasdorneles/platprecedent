.PHONY: game.love clean
game.love:
	# git archive --format=zip --output game.love main
	zip -r game.love *.lua vendor maps images

game-web-build: game.love
	love.js game.love game-web-build --compatibility --title "Plat Précedent"

release-web: game-web-build
	uvx ghp-import -m "Deploy to GitHub Pages" game-web-build
	git push origin gh-pages --force

server: game-web-build
	python3 -m http.server 8000 --directory game-web-build

clean:
	rm -rf game.love game-web-build
