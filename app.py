from flask import Flask, send_from_directory, jsonify, Response, request
import subprocess

app = Flask(__name__, static_folder='static')

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/run', methods=['POST'])
def run_recon():
    data = request.json
    domain = data.get('domain')
    task = data.get('task')

    if not domain or not task:
        return jsonify({'error': 'Domain and task are required!'}), 400

    # Path to the script
    script_path = './recon_ubuntu.sh'

    try:
        # Execute the script
        process = subprocess.Popen(
            [script_path, domain, task],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        def generate_output():
            for line in process.stdout:
                yield f"{line}\n"
            process.wait()
            if process.returncode != 0:
                yield f"Error: {process.stderr.read()}\n"

            # Provide the location of the result file
            #yield f"Task completed. Download results at: ./results/{domain}\n"

        return Response(generate_output(), mimetype='text/plain')
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
